# Generate Nushell vendor autoload files for shell integrations.
#
# Output: $nu.data-dir/vendor/autoload/<NN>-<tool>.nu. Nushell loads these
# after config.nu and before the user autoload directory, in name order.
#
# Generated once, not at every shell start: no startup cost. The catch is
# that some generators embed the absolute, versioned path of their binary
# (starship does), so this must run again after every mise upgrade. The
# chezmoi run_onchange script and `just upgrade` both call it.
#
# A tool missing from PATH gets its file removed, so startup never fails
# on a stale integration.

use std/util "path add"

const INTEGRATIONS = [
    [file              tool        args];
    ["00-mise.nu"      "mise"      ["activate" "nu" "--quiet"]]
    ["10-starship.nu"  "starship"  ["init" "nu"]]
    ["20-zoxide.nu"    "zoxide"    ["init" "nushell"]]
    ["30-atuin.nu"     "atuin"     ["init" "nu"]]
    ["40-carapace.nu"  "carapace"  ["_carapace" "nushell"]]
]

def main [] {
    # chezmoi may start this from a non-activated environment (first bootstrap):
    # make mise and its shims reachable explicitly.
    let shims = if $nu.os-info.name == "windows" {
        $env.LOCALAPPDATA | path join "mise" "shims"
    } else {
        "~/.local/share/mise/shims" | path expand
    }
    path add $shims ("~/.local/bin" | path expand)

    let dir = ($nu.data-dir | path join "vendor" "autoload")
    mkdir $dir

    for i in $INTEGRATIONS {
        let target = ($dir | path join $i.file)
        if (which $i.tool | is-empty) {
            rm -f $target
            print $"skip  ($i.tool): not on PATH, removed ($target)"
            continue
        }
        let out = (run-external $i.tool ...$i.args | complete)
        if $out.exit_code != 0 {
            error make {msg: $"($i.tool) ($i.args | str join ' ') failed:\n($out.stderr)"}
        }
        $out.stdout | save -f $target
        print $"ok    ($target)"
    }
}
