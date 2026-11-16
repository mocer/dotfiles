# Guard shared by upgrade.nu and upgrade-nu.nu.
#
# `chezmoi re-add` copies the installed file over the source. If the source has
# changes that were never applied, re-add would silently discard them. So the
# mise configuration must be in sync before anything touches it.
# The guard only reports: it never applies or re-adds anything itself.

# Parse `chezmoi status` lines ("XY path") into {path, source, home} records.
# Column 1: the installed file changed since chezmoi last wrote it (not re-added).
# Column 2: the source differs from the installed file (not applied).
export def classify [status: string]: nothing -> table {
    $status
    | lines
    | where {|line| ($line | str trim) != "" }
    | each {|line|
        {
            path: ($line | str substring 3..)
            home: (($line | str substring 0..0) != " ")
            source: (($line | str substring 1..1) != " ")
        }
    }
}

# Stop with exit code 1 unless `chezmoi status ~/.config/mise` is empty.
export def check-mise-config []: nothing -> nothing {
    let dir = ($nu.home-dir | path join ".config" "mise")
    let out = (^chezmoi status $dir | complete)
    if $out.exit_code != 0 {
        print -e $"chezmoi status failed:\n($out.stderr | str trim)"
        exit 1
    }

    let entries = (classify $out.stdout)
    if ($entries | is-empty) { return }

    let lines = ($entries | each {|e|
        let kind = if $e.source and $e.home {
            "source changed and home changed"
        } else if $e.source {
            "source changed, not applied"
        } else {
            "home changed, not re-added"
        }
        $"  ($e.path)  [($kind)]"
    } | str join "\n")

    print -e $"
The mise configuration is not in sync between the dotfiles source and the home directory:

($lines)

Stopping before anything is changed: `chezmoi re-add` would overwrite unapplied source changes.
Inspect first:  chezmoi diff ($dir)

  source changed, not applied -> chezmoi apply ($dir)
  home changed, not re-added  -> chezmoi re-add ($dir)

If both apply to the same file, decide which side wins, then run only that command.
This script never fixes it automatically."
    exit 1
}
