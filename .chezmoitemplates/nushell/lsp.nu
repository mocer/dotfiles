{{- $win := eq .chezmoi.os "windows" -}}
{{- $shims := ternary (joinPath (env "LOCALAPPDATA") "mise" "shims") (joinPath .chezmoi.homeDir ".local" "share" "mise" "shims") $win -}}
# Minimal configuration for `nu --lsp` (Zed and Helix).
# Managed by chezmoi: edit .chezmoitemplates/nushell/lsp.nu in the dotfiles repository.
# Must never print: stdout is the LSP channel.
use std/util "path add"

path add ...([
    {{ $shims | toJson }}
    ($nu.home-dir | path join ".local" "bin")
    ($nu.home-dir | path join ".cargo" "bin")
] | where {|d| $d | path exists })

$env.config.show_banner = false
