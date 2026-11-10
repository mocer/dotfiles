{{- /*
  Nushell environment, loaded first, before config.nu.
  Environment only: interactive setup lives in config.nu and autoload/.
  Values that GUI apps (Zed) must also see stay in tool config files and are
  mirrored here:
  - ~/.cargo/config.toml  [env] SCCACHE_*
*/ -}}
{{- $win := eq .chezmoi.os "windows" -}}
{{- $home := .chezmoi.homeDir -}}
{{- $shims := ternary (joinPath (env "LOCALAPPDATA") "mise" "shims") (joinPath $home ".local" "share" "mise" "shims") $win -}}
{{- $cargoConfig := joinPath $home ".cargo" "config.toml" -}}
{{- $ghrRoot := get . "ghr_root" | default "~/Repos" -}}
{{- if hasPrefix "~/" $ghrRoot }}{{ $ghrRoot = joinPath $home (trimPrefix "~/" $ghrRoot) }}{{ end -}}
# Managed by chezmoi: edit env.nu.tmpl in the dotfiles repository.

use std/util "path add"

# ── PATH ─────────────────────────────────────────────────────────────
# Highest priority first; missing directories are skipped (as fish_add_path did).
# `path add` handles PATH/Path on Windows and removes duplicates.
# mise activation (vendor autoload) later puts the active tool versions
# ahead of the shims.
let user_paths = [
    {{ $shims | toJson }}
    {{ joinPath $home ".local" "bin" | toJson }}
    {{ joinPath $home ".cargo" "bin" | toJson }}
{{- if eq .chezmoi.os "darwin" }}
    {{ joinPath $home ".orbstack" "bin" | toJson }}
    "/opt/local/bin"
    "/usr/local/bin"
{{- end }}
] | where {|dir| $dir | path exists }
if ($user_paths | is-not-empty) { path add ...$user_paths }

# ── Rust ─────────────────────────────────────────────────────────────
# Panic backtraces for binaries started from the shell.
$env.RUST_BACKTRACE = "1"

# ── sccache ──────────────────────────────────────────────────────────
# Single source of truth: [env] in ~/.cargo/config.toml.
# Mirrored here so a server started from the shell gets the same values.
if ({{ $cargoConfig | toJson }} | path exists) {
    open {{ $cargoConfig | toJson }}
    | get env?
    | default {}
    | transpose key value
    | where {|row| ($row.key | str starts-with "SCCACHE_") and (($row.value | describe) == "string") }
    | reduce --fold {} {|row, acc| $acc | insert $row.key $row.value }
    | load-env
}

# ── Tools ────────────────────────────────────────────────────────────
$env.GHR_ROOT = {{ $ghrRoot | toJson }}
$env._ZO_FZF_OPTS = ""
$env._ZOXIDE_FZF_CMD = "sk --height 40% --layout=reverse --border rounded"
{{- if not $win }}
$env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"

# ── Locale ───────────────────────────────────────────────────────────
# Same three variables the Fish configuration exported.
$env.LANG = {{ .locale | toJson }}
$env.LANGUAGE = {{ .locale | toJson }}
$env.LC_ALL = {{ .locale | toJson }}
{{- end }}
