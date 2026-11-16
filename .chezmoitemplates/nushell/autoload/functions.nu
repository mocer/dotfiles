# Personal commands, ported from ~/.config/fish/functions.
# Managed by chezmoi: edit .chezmoitemplates/nushell/autoload/functions.nu.
#
# skim runs --preview commands through a shell: the preview strings below
# are valid in both sh and Nushell on purpose (no redirections, no `&&`).
#
# Fish completion files are no longer needed for these commands: argument
# types in the signatures (directory, string) give native completion.

# Pick a file with fd + skim. Returns "" when the selection is cancelled.
def sk-pick-file [root: directory] {
    try {
        ^fd --type f . $root
        | ^sk --prompt "Pick a file> " --preview "bat --color=always --style=numbers {}"
        | str trim
    } catch { "" }
}

# Fuzzy-find a file and open it in Helix (optional root directory).
def skh [root: directory = "."] {
    let file = (sk-pick-file $root)
    if ($file | is-not-empty) { ^hx $file }
}

# Fuzzy-find a file and open it in Zed (optional root directory).
def skz [root: directory = "."] {
    let file = (sk-pick-file $root)
    if ($file | is-not-empty) { ^zed $file }
}

# Fuzzy-open a file from the chezmoi source directory.
def skdc [] { skh (^chezmoi source-path | str trim) }

# Fuzzy-open a file from ~/.config.
def skcc [] { skh ("~/.config" | path expand) }

# Search file contents with ripgrep and open the selected match in Helix.
def skrg [pattern: string] {
    let pick = try {
        ^rg --line-number --no-heading --color=never $pattern
        | ^sk --prompt "Pick a match> " --delimiter ":" --preview "bat --color=always --style=numbers --highlight-line {2} {1}"
        | str trim
    } catch { "" }
    if ($pick | is-empty) { return }

    let parts = ($pick | split row ":")
    ^hx $"($parts.0):($parts.1)"
}

# Fuzzy-pick a repository managed by ghr and cd into it.
def --env repo [...query: string] {
    let selected = try {
        ^ghr list --path
        | ^sk --prompt "Pick a repo> " --query ($query | str join " ") --preview "eza --tree --level=2 --icons --color=always {}"
        | str trim
    } catch { "" }
    # Plain cd: zoxide's PWD hook still records the visit.
    if ($selected | is-not-empty) { cd $selected }
}

# True when the file looks binary: a NUL byte in the first 8 KiB (same heuristic as Git).
def is-binary [file: path] {
    (open --raw $file | into binary | first 8192 | bytes index-of 0x[00]) != -1
}

# Dump the textual files of the current repository into one file in the temp
# directory. Prints the location on stderr and returns the path.
def repo-dump [] {
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let out = ($nu.temp-dir | path join $"($env.PWD | path basename)-($stamp).txt")
    let excludes = [
        ".git" ".jj" "node_modules" "target" "dist" "build"
        ".direnv" ".mise" ".cache" ".next" "coverage"
    ]

    let tree = if (which eza | is-not-empty) {
        ^eza --tree --git-ignore --level=5 | complete | get stdout
    } else {
        glob "**/*" --depth 5 | path relative-to $env.PWD | str join "\n"
    }

    let files = (
        ^fd --type file --hidden ...($excludes | each {|e| ["--exclude" $e] } | flatten) .
        | lines
        | where {|f| not (is-binary $f) }
    )

    let sections = ($files | each {|f|
        let body = if (which bat | is-not-empty) {
            ^bat --plain --color=never --paging=never $f
        } else {
            open --raw $f | decode utf-8
        }
        $"\n\n===== FILE: ($f) =====\n($body)\n===== END FILE: ($f) ====="
    })

    [
        "===== REPOSITORY =====" $env.PWD ""
        "===== TREE =====" $tree ""
        "===== FILES =====" ...$sections
    ] | str join "\n" | save -f $out

    print -e $"Dump done: ($out)"
    $out
}

# Run the dotfiles upgrade workflow (the `upgrade` recipe of the dotfiles justfile).
def system_upgrade [] {
    for cmd in ["chezmoi" "just"] {
        if (which $cmd | is-empty) { error make {msg: $"($cmd) is not available in PATH."} }
    }

    let source_dir = (^chezmoi source-path | str trim)
    let justfile = ($source_dir | path join "justfile")
    if not ($justfile | path exists) {
        error make {msg: $"dotfiles justfile not found: ($justfile)"}
    }

    print "==> Running the dotfiles system upgrade workflow"
    ^just --justfile $justfile --working-directory $source_dir upgrade
    if $env.LAST_EXIT_CODE != 0 { error make {msg: "system upgrade failed."} }

    print "\nSystem upgrade completed successfully."
}
