# Maintain stable ~/.local/bin/<tool> links to the binaries resolved by mise.
#
# Native applications (Alacritty, Zed, IINA, Cargo) do not inherit the shell
# environment activated by mise. They use these stable paths instead of:
# - the versioned mise install path, which changes on every upgrade;
# - a mise shim, which still depends on mise runtime resolution.
#
# macOS/Linux: symbolic link ~/.local/bin/<tool>, replaced atomically.
# Windows:     hard link %USERPROFILE%\.local\bin\<tool>.exe via `mklink /H`
#              (no Developer Mode or elevation needed, same volume only).
#              A hard link is a snapshot: run this script after every upgrade.
#
# Usage: nu scripts/refresh-links.nu [tool ...]    (default: nu deno sccache)

use std/util "path add"

const DEFAULT_TOOLS = ["nu" "deno" "sccache"]

def main [...tools: string] {
    let tools = if ($tools | is-empty) { $DEFAULT_TOOLS } else { $tools }
    let bin_dir = ($nu.home-dir | path join ".local" "bin")
    mkdir $bin_dir
    # mise itself lives here; chezmoi may start this from a non-activated environment.
    path add $bin_dir

    for tool in $tools {
        let target = (resolve-tool $tool)
        if $nu.os-info.name == "windows" {
            link-windows $tool $target $bin_dir
        } else {
            link-unix $tool $target $bin_dir
        }
    }
}

# Absolute path of the binary mise resolves for <tool>.
def resolve-tool [tool: string]: nothing -> string {
    let resolved = (^mise which $tool | complete)
    let target = ($resolved.stdout | str trim)
    if $resolved.exit_code != 0 or ($target | is-empty) {
        error make {msg: $"mise could not resolve '($tool)': add it to the global mise configuration"}
    }
    if not ($target | path exists) {
        error make {msg: $"the binary mise resolved for '($tool)' does not exist: ($target)"}
    }
    $target
}

def link-unix [tool: string, target: string, bin_dir: string] {
    let link = ($bin_dir | path join $tool)
    let kind = ($link | path type | default "")
    if $kind != "" and $kind != "symlink" {
        error make {msg: $"refusing to replace a non-symlink path: ($link)"}
    }

    if $kind == "symlink" and (^readlink $link | str trim) == $target {
        print $"ok    ($tool): already current -> ($target)"
        return
    }

    # Atomic replacement: create the new link aside, then rename over the old one.
    let tmp = $"($link).new"
    rm -f $tmp
    ^ln -s $target $tmp
    ^mv -f $tmp $link
    print $"ok    ($tool): ($link) -> ($target)"
}

def link-windows [tool: string, target: string, bin_dir: string] {
    let link = ($bin_dir | path join $"($tool).exe")
    let old = $"($link).old"

    # A hard link has no readable target: compare content instead.
    if ($link | path exists) and (file-hash $link) == (file-hash $target) {
        print $"ok    ($tool): already current -> ($target)"
        return
    }

    # A running .exe cannot be overwritten, but it can be renamed.
    if ($old | path exists) { rm -f $old }
    if ($link | path exists) { mv $link $old }

    let out = (^cmd /c mklink /H $link $target | complete)
    if $out.exit_code != 0 {
        if ($old | path exists) { mv $old $link }
        error make {msg: $"mklink /H failed for ($tool) \(the link and the mise install must be on the same volume\):\n($out.stdout)($out.stderr)"}
    }

    # Best effort: the old binary may still be running.
    try { rm -f $old }
    print $"ok    ($tool): ($link) => ($target)"
}

def file-hash [file: path]: nothing -> string {
    open --raw $file | hash sha256
}
