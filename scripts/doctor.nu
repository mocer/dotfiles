# Verify the main development environment prerequisites. Entry point of `just doctor`.
# Runs every check, prints one line each, and exits 1 when any check failed.
#
# --skip-activation: do not require mise to be activated in the calling shell
#                    (used by scripts that run outside an interactive session).

const LINKED_TOOLS = ["nu" "deno" "sccache"]
const VENDOR_FILES = ["00-mise.nu" "10-starship.nu" "20-zoxide.nu" "30-atuin.nu" "40-carapace.nu"]
const NU_TOOL = "aqua:nushell/nushell"

def main [--skip-activation] {
    mut results = []

    for cmd in ["mise" "chezmoi" "rustup" "uv" "just" "nu"] {
        $results = ($results | append (check (which $cmd | is-not-empty) $"($cmd) on PATH"))
    }

    if not $skip_activation {
        let activated = (^mise doctor | complete | get stdout | str contains "activated: yes")
        $results = ($results | append (check $activated "mise activated in this shell" "just nushell-init, then open a new shell"))
    }

    let missing = (^mise ls --missing | complete | get stdout | str trim)
    $results = ($results | append (check ($missing | is-empty) "no mise tool missing" "mise install"))

    let bin_dir = ($nu.home-dir | path join ".local" "bin")
    for tool in $LINKED_TOOLS {
        $results = ($results | append (check-link $tool $bin_dir))
    }

    let autoload = ($nu.data-dir | path join "vendor" "autoload")
    for file in $VENDOR_FILES {
        $results = ($results | append (check ($autoload | path join $file | path exists) $"vendor autoload ($file)" "just nushell-init"))
    }

    # `~/.cargo/bin/rust-analyzer` is a rustup proxy that exists even without the component.
    let analyzer = (do { ^rust-analyzer --version } | complete)
    $results = ($results | append (check ($analyzer.exit_code == 0) "rust-analyzer runs" "rustup component add rust-analyzer"))

    let running = (version | get version)
    let pinned = (open ($nu.home-dir | path join ".config" "mise" "config.toml") | get tools | get $NU_TOOL)
    $results = ($results | append (check ($running == $pinned) $"nu ($running) matches the pin ($pinned)" "just upgrade-nu <version>"))

    $results = ($results | append (check ($nu.home-dir | path join ".config" "git" "ignore" | path exists) "global Git ignore"))

    for r in $results {
        if $r.ok {
            print $"ok    ($r.label)"
        } else {
            let hint = if ($r.hint | is-empty) { "" } else { $"  -> ($r.hint)" }
            print $"FAIL  ($r.label)($hint)"
        }
    }

    let failed = ($results | where ok == false | length)
    if $failed > 0 {
        print -e $"\n($failed) check\(s\) failed."
        exit 1
    }
    print "\nAll checks passed."
}

def check [ok: bool, label: string, hint: string = ""]: nothing -> record {
    {ok: $ok, label: $label, hint: $hint}
}

# The stable link must match what mise resolves.
# Unix: symlink target. Windows: hard links have no readable target, compare `--version`.
def check-link [tool: string, bin_dir: string]: nothing -> record {
    let resolved = (^mise which $tool | complete)
    if $resolved.exit_code != 0 {
        return (check false $"($tool) resolved by mise" "add it to the mise configuration")
    }
    let expected = ($resolved.stdout | str trim)

    if $nu.os-info.name == "windows" {
        let link = ($bin_dir | path join $"($tool).exe")
        let same = if ($link | path exists) {
            (^$link --version | complete | get stdout | str trim) == (^$expected --version | complete | get stdout | str trim)
        } else { false }
        check $same $"($link) matches mise ($tool)" "just refresh-links"
    } else {
        let link = ($bin_dir | path join $tool)
        let actual = (^readlink $link | complete | get stdout | str trim)
        check ($actual == $expected) $"($link) -> ($expected)" "just refresh-links"
    }
}
