# Upgrade every mise tool except the held ones, then apply the result.
# Entry point of `just upgrade` (and of the `system_upgrade` command).
#
# Nushell is held: the repository's Nushell code targets one version.
# Move it deliberately with `just upgrade-nu <version>`.
#
# On Windows it also upgrades the winget applications, as the final step.
#
# Generated state (mise install, stable links, Nushell integrations) is not
# refreshed here: `chezmoi apply` re-runs the run_onchange scripts because the
# mise configuration hash changed.

use std/util "path add"
use mise-guard.nu check-mise-config

const HELD = ["aqua:nushell/nushell"]

# No --include-unknown: it would also upgrade software winget did not install.
const WINGET_ARGS = [
    "upgrade" "--all" "--silent" "--disable-interactivity"
    "--accept-package-agreements" "--accept-source-agreements"
]

def main [] {
    # Not guaranteed when started from a non-activated environment.
    path add ($nu.home-dir | path join ".local" "bin") ($nu.home-dir | path join ".cargo" "bin")

    step "mise self-update"
    warn-on-failure "mise self-update failed, continuing with the current mise" {
        ^mise self-update -y | complete
    }

    step "chezmoi upgrade"
    warn-on-failure "chezmoi upgrade failed (package-manager installs refuse self-upgrade), continuing" {
        ^chezmoi upgrade | complete
    }

    step "check that the mise configuration is in sync"
    check-mise-config

    step "mise upgrade --bump (except held tools)"
    # Names from `mise ls --current` are the identifiers `mise upgrade` accepts.
    let tools = (^mise ls --current --json | from json | columns | where {|tool| $tool not-in $HELD })
    ^mise upgrade --bump ...$tools

    step "chezmoi re-add ~/.config/mise"
    ^chezmoi re-add ($nu.home-dir | path join ".config" "mise")

    step "chezmoi apply"
    ^chezmoi apply

    step "rustup update"
    ^rustup update

    step "uv tool upgrade --all"
    ^uv tool upgrade --all

    step "Uncommitted changes in the dotfiles repository"
    let source = (^chezmoi source-path | str trim)
    ^git -C $source status --short

    if $nu.os-info.name == "windows" {
        step "winget upgrade (applications)"
        winget-upgrade
    }

    print "\nUpgrade completed."
}

def step [title: string] {
    print $"\n==> ($title)"
}

# Windows only: applications installed by bootstrap-windows.ps1.
# Last step: an installer may close the terminal running this script (Alacritty).
# gsudo gives one UAC prompt for the whole run; without it winget asks UAC once
# per machine-scope package. Rustup and App Installer are pinned by the
# bootstrap. Never fails the upgrade.
def winget-upgrade [] {
    if (which winget | is-empty) {
        print -e "warning: winget not found, applications skipped"
        return
    }
    try {
        if (which gsudo | is-not-empty) {
            ^gsudo winget ...$WINGET_ARGS
        } else {
            ^winget ...$WINGET_ARGS
        }
    } catch {
        print -e $"warning: winget upgrade ended with exit code ($env.LAST_EXIT_CODE); check `winget upgrade`"
    }
}

# Run a closure returning a `complete` record. Print its output on success,
# a warning with its stderr otherwise; never fail.
def warn-on-failure [message: string, action: closure] {
    let out = (do $action)
    if $out.exit_code == 0 {
        print ($out.stdout | str trim)
    } else {
        print -e $"warning: ($message)\n($out.stderr | str trim)"
    }
}
