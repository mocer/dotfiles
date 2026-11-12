# Move Nushell to <version>. Entry point of `just upgrade-nu <version>`.
#
# Installs the version, refreshes the stable link, checks every Nushell file of
# the repository with the new binary, and runs the doctor. On any error the
# previous version is restored and the script fails.
#
# Usage: nu scripts/upgrade-nu.nu <version>

use std/util "path add"

const NU_TOOL = "aqua:nushell/nushell"
const SCRIPTS = path self | path dirname
# Files rendered by chezmoi into the Nushell config directory.
const CONFIG_FILES = ["env.nu" "config.nu" "lsp.nu" "autoload/functions.nu"]

def main [version: string] {
    if ($version !~ '^\d+\.\d+\.\d+$') {
        error make {msg: $"expected a version like 0.117.0, got '($version)'"}
    }
    path add ($nu.home-dir | path join ".local" "bin") ($nu.home-dir | path join ".cargo" "bin")

    let mise_config = ($nu.home-dir | path join ".config" "mise" "config.toml")
    let previous = (open $mise_config | get tools | get $NU_TOOL)
    if $previous == $version {
        print $"Nushell is already pinned to ($version)."
        return
    }

    print $"==> Nushell ($previous) -> ($version)"
    try {
        install-and-check $version
    } catch {|err|
        print -e $"\nupgrade-nu failed: ($err.msg)\nRestoring Nushell ($previous)."
        use-version $previous
        error make {msg: $"Nushell stays at ($previous)"}
    }

    ^chezmoi re-add ($nu.home-dir | path join ".config" "mise")
    ^$nu.current-exe ($SCRIPTS | path join "nushell-init.nu")
    print $"\nNushell is now ($version). Restart open shells."
}

# Pin and install <version> through mise, then refresh the stable link.
def use-version [version: string] {
    ^mise use --global $"($NU_TOOL)@($version)"
    # The link must point at the new binary before the doctor compares them.
    ^$nu.current-exe ($SCRIPTS | path join "refresh-links.nu")
}

def install-and-check [version: string] {
    use-version $version
    let new_nu = (^mise which nu | str trim)

    let reported = (^$new_nu --version | str trim)
    if $reported != $version {
        error make {msg: $"the new binary reports ($reported), expected ($version)"}
    }

    print "==> Checking repository scripts"
    for file in (glob ($SCRIPTS | path join "*.nu")) {
        ide-check $new_nu $file
    }

    print "==> Checking the rendered Nushell configuration"
    let config_dir = (^$new_nu -c '$nu.default-config-dir' | str trim)
    let tmp = ($nu.temp-dir | path join $"upgrade-nu-(random uuid)")
    mkdir $tmp
    try {
        for name in $CONFIG_FILES {
            let rendered = ($tmp | path join ($name | path basename))
            ^chezmoi cat ($config_dir | path join $name) | save -f $rendered
            ide-check $new_nu $rendered
        }
    } catch {|err|
        rm -rf $tmp
        error make {msg: $err.msg}
    }
    rm -rf $tmp

    print "==> Running the doctor"
    # Activation is a property of the calling shell, not of the installed tools.
    ^$new_nu ($SCRIPTS | path join "doctor.nu") --skip-activation
}

# Fail when `nu --ide-check` reports a diagnostic (hints are not errors).
def ide-check [nu_exe: string, file: path] {
    let out = (^$nu_exe --ide-check 100 $file | complete)
    let diagnostics = (
        $out.stdout | lines
        | where {|line| $line | str starts-with "{" }
        | each {|line| $line | from json }
        | where {|entry| ($entry.type? | default "") == "diagnostic" }
    )
    if ($diagnostics | is-not-empty) {
        error make {msg: $"($file): ($diagnostics | length) diagnostic\(s\), first: ($diagnostics | first | to nuon)"}
    }
}
