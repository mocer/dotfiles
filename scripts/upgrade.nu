# Upgrade every mise tool except the held ones, then refresh generated state.
# Entry point of `just upgrade` (and of the `system_upgrade` command).
#
# Nushell is held: the repository's Nushell code targets one version.
# Move it deliberately with `just upgrade-nu <version>`.

use std/util "path add"

const HELD = ["aqua:nushell/nushell"]
const SCRIPTS = path self | path dirname

def main [] {
    # Not guaranteed when started from a non-activated environment.
    path add ($nu.home-dir | path join ".local" "bin") ($nu.home-dir | path join ".cargo" "bin")

    step "mise self-update"
    let update = (^mise self-update -y | complete)
    if $update.exit_code == 0 {
        print ($update.stdout | str trim)
    } else {
        print -e $"warning: mise self-update failed, continuing with the current mise\n($update.stderr | str trim)"
    }

    step "mise upgrade --bump (except held tools)"
    # Names from `mise ls --current` are the identifiers `mise upgrade` accepts.
    let tools = (^mise ls --current --json | from json | columns | where {|tool| $tool not-in $HELD })
    ^mise upgrade --bump ...$tools

    step "mise reshim"
    ^mise reshim

    step "chezmoi re-add ~/.config/mise"
    ^chezmoi re-add ($nu.home-dir | path join ".config" "mise")

    step "refresh links and Nushell integrations"
    ^$nu.current-exe ($SCRIPTS | path join "refresh-links.nu")
    ^$nu.current-exe ($SCRIPTS | path join "nushell-init.nu")

    step "rustup update"
    ^rustup update

    step "uv tool upgrade --all"
    ^uv tool upgrade --all

    print "\nUpgrade completed."
}

def step [title: string] {
    print $"\n==> ($title)"
}
