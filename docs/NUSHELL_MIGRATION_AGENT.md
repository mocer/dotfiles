# Agent instructions: migrate the dotfiles from Fish to Nushell

## 0. Goal and ground rules

Move the interactive shell, personal commands, chezmoi scripts, and the
justfile from Fish to Nushell. The same source tree must run **natively** on
macOS, Linux, and Windows. **WSL2 is out of scope**: remove every WSL code path.

Prerequisites, already installed by the user before `chezmoi init`:
Zed, Alacritty, Git, Rust (rustup), chezmoi, mise.
Everything else (including Nushell) is installed by mise from the dotfiles.

Rules for the agent:

1. **Inspect before editing.** File names below come from a previous review.
   Confirm each one exists (`chezmoi managed`, `fd`, `rg`) before changing it.
   If a file differs from what is described here, follow the intent of the
   step and report the difference. Do not invent files or settings.
2. **One phase at a time.** Finish the verification of each phase before
   starting the next. Commit after each phase with a message naming the phase.
3. **Keep responsibilities separate**: chezmoi = files and run scripts,
   mise = tools and versions, rustup = Rust toolchain, Nushell = shell
   and scripts, just = maintenance entry points. No circular calls.
4. **No new tools** beyond those listed here (carapace is the only addition).
5. All comments and docs in English, direct, consistent with the existing style.
6. Never print secrets; never decrypt or re-encrypt `age` files.
7. Stop and ask the user when a step conflicts with what you find.

---

## 1. Repository hygiene (Windows prerequisite)

Windows Git may convert line endings to CRLF. A CRLF shebang or `.nu`
script breaks on Unix, and Nushell scripts must stay byte-identical across OSes.

- Create or extend `.gitattributes` at the repository root:
  ```gitattributes
  * text=auto eol=lf
  *.ps1 text eol=crlf
  *.age binary
  ```
- Add `.gitattributes` to `.chezmoiignore` (repository-only file).
- Run `git add --renormalize .` and commit separately.

**Verify:** `git ls-files --eol | rg crlf` lists only `.ps1` files.

---

## 2. mise configuration

### 2.1 Rust belongs to rustup

Rust is a prerequisite installed with rustup. If `dot_config/mise/config.toml`
declares `rust`, remove it: two managers for one toolchain cause PATH
precedence bugs and duplicate upgrades. The cargo backend only needs `cargo`
on PATH.

### 2.2 Nushell from a prebuilt release

Nushell is required by every later chezmoi script, so it must install fast
and reliably on the first `chezmoi apply`, including Windows (a source build
there needs the MSVC Build Tools and takes many minutes).

- Replace `cargo:nu` with a prebuilt backend. Prefer `aqua:nushell/nushell`;
  if `mise registry | rg nushell` shows a different default, use that.
- Pin an explicit version (≥ 0.101; the config relies on `std/util "path add"`,
  `$nu.home-dir`, and the user autoload directory).

### 2.3 Forced source builds

The old workaround `default-features = true` no longer disables cargo-binstall:
current mise forces `cargo install` only with `features` or
`default-features = false`.

- For every crate that must compile locally, replace `default-features = true`
  with `features = "<feature>"`. Check the feature exists first:
  `cargo info <crate>@<version>` (use `default` when it is listed; ripgrep
  has no `default` feature: use `pcre2`).
- Verify with `mise install -f cargo:<crate>@<version> --verbose`: the log
  must show `cargo install`, not `cargo-binstall`.
- If the comments mention `RUSTFLAGS`/`target-cpu=native` but nothing sets
  them, fix the comment. Do not add global `RUSTFLAGS` to `~/.cargo/config.toml`.

### 2.4 Additions and removals

- Add `carapace` (external completions for Nushell).
- Keep `aqua:fish-shell/fish-shell` until Phase 9, then remove it.
- Remove any tool used only by Fish (`fish_indent` integration in Helix, etc.)
  in Phase 9.

### 2.5 `mise upgrade --bump` and chezmoi

`just upgrade` bumps pinned versions in `~/.config/mise/config.toml` and then
runs `chezmoi re-add`. `re-add` **skips templates and encrypted files**.

- Confirm `dot_config/mise/config.toml` is a plain file (no `.tmpl`, no
  `encrypted_`). If it is a template, move the templated parts to
  `conf.d/*.toml` files gated by `.chezmoiignore` and keep `config.toml` plain.
- Profile files (`conf.d/poste.toml`, `conf.d/mobile.toml`) follow the same rule.

**Verify:** `mise ls --missing` is empty; `mise which nu` and `mise which carapace`
resolve on the current OS; `chezmoi re-add ~/.config/mise` changes the source.

---

## 3. Native per-OS paths, without symlinks

On Windows, chezmoi symlinks require Developer Mode or elevation. Do not use
`symlink_` entries. Instead, render the same shared template at the path each
application actually reads.

| Application | macOS | Linux | Windows |
| --- | --- | --- | --- |
| Nushell | `~/Library/Application Support/nushell` | `~/.config/nushell` | `%APPDATA%\nushell` |
| Alacritty | `~/.config/alacritty` | `~/.config/alacritty` | `%APPDATA%\alacritty` |
| Zed | `~/.config/zed` | `~/.config/zed` | `%APPDATA%\Zed` |
| Helix | `~/.config/helix` | `~/.config/helix` | `%APPDATA%\helix` |

`~/.config` is read on every OS by: mise, starship, chezmoi, git, bat, atuin.
Leave those where they are.

Confirm each path with the application (`nu -c '$nu.default-config-dir'`,
`hx --health` header, Zed and Alacritty docs) before moving files.

Pattern:

1. Move the file content to `.chezmoitemplates/<app>/<file>`
   (e.g. `.chezmoitemplates/nushell/config.nu`).
2. Create thin target files per location, each containing only
   `{{ template "<app>/<file>" . }}`, e.g.:
   - `dot_config/nushell/config.nu.tmpl`
   - `Library/Application Support/nushell/config.nu.tmpl`
   - `AppData/Roaming/nushell/config.nu.tmpl`
3. In `.chezmoiignore`, keep only the location of the current OS:
   ```
   {{ if ne .chezmoi.os "darwin" }}
   Library
   {{ end }}
   {{ if ne .chezmoi.os "windows" }}
   AppData
   {{ end }}
   {{ if ne .chezmoi.os "linux" }}
   .config/nushell
   {{ end }}
   ```
   Apply the same logic to Alacritty, Zed, Helix: on Windows ignore their
   `.config/<app>` target.
4. Templates that call `.chezmoi.os` keep working unchanged: the thin file
   passes the full context (`.`).

**Verify on each OS:** `chezmoi managed | rg -i "nushell|alacritty|zed|helix"`
shows exactly one location per application.

---

## 4. Nushell configuration

Files (shared templates, rendered as in Phase 3):

| File | Content |
| --- | --- |
| `env.nu` | PATH, environment variables only |
| `config.nu` | `$env.config`, aliases, greeting under `if $nu.is-interactive` |
| `autoload/functions.nu` | personal commands |
| `lsp.nu` | minimal config for `nu --lsp`; must never print |

Load order: `env.nu` → `config.nu` → vendor autoload → user `autoload/`.

### 4.1 `env.nu`

- `use std/util "path add"`; add, highest priority first, only existing
  directories: mise shims (`~/.local/share/mise/shims`, Windows
  `%LOCALAPPDATA%\mise\shims`), `~/.local/bin`, `~/.cargo/bin`, and the
  macOS-only extra paths currently in the Fish config.
- Port every `set -gx` from `config.fish`. Unix-only variables (`MANPAGER`
  using `sh`, locale `LANG`/`LANGUAGE`/`LC_ALL`) are rendered only when
  `.chezmoi.os` is not `windows`.
- sccache variables: read them from `[env]` in `~/.cargo/config.toml`
  (single source of truth), filter keys starting with `SCCACHE_`, `load-env`.
- Set `GHR_ROOT` from chezmoi data with a default.

### 4.2 `config.nu`

- `show_banner = false`, `buffer_editor = "hx"`,
  `shell_integration.osc2 = true` (replaces `fish_title`/`fish_tab_title`),
  `shell_integration.osc7 = true`.
- Convert every Fish abbreviation to an `alias`. Keep the built-in `ls`
  (structured output); expose eza as `l`, `ll`, `la`, `lt`, `llt`.
- Greeting: `if $nu.is-interactive { print "…" }`.

### 4.3 `autoload/functions.nu`

Port these Fish functions: `skh`, `skz`, `skdc`, `skcc`, `skrg`, `repo`,
`repo-dump`, `system_upgrade`. Drop: `fish_prompt` (starship),
`fish_title`/`fish_tab_title` (osc2), `print_colors` (`ansi --list`).
Drop every `completions/*.fish`: signatures give completion for own commands,
carapace covers external ones.

Constraints:
- Use typed parameters (`directory`, `string`, `path`).
- Wrap `sk` in `try`/`catch` (cancel returns non-zero).
- `repo` is `def --env` and uses plain `cd`.
- `repo-dump`: output in `$nu.temp-dir`; binary detection via a NUL byte in
  the first 8 KiB (no `file(1)`, which Windows lacks).
- skim previews run through the platform shell (`cmd` on Windows): keep the
  preview strings to a single command with arguments, no pipes or redirections.

### 4.4 `ghr`

`ghr shell` supports only bash and fish. Do **not** emulate it. `repo` covers
navigation; remove the `ghr shell fish | source` line from the Fish config
when Fish is retired.

### 4.5 Vendor autoload generator

Create `scripts/nushell-init.nu`. It writes one file per integration into
`$nu.data-dir/vendor/autoload/`:

| File | Command |
| --- | --- |
| `00-mise.nu` | `mise activate nu` |
| `10-starship.nu` | `starship init nu` |
| `20-zoxide.nu` | `zoxide init nushell` |
| `30-atuin.nu` | `atuin init nu` |
| `40-carapace.nu` | `carapace _carapace nushell` |

- Add mise shims and `~/.local/bin` to PATH inside the script (it runs from a
  non-activated environment during bootstrap).
- If a tool is not on PATH, delete its file instead of failing.
- Fail on non-zero exit of a generator.
- Starship embeds its versioned binary path: the script must run again after
  every upgrade (Phase 5 and Phase 7).

### 4.6 Language server

`nu --lsp` is the language server; Zed and Helix share it with `lsp.nu`:

```nu
# Minimal configuration for `nu --lsp`. Must never print: stdout is the LSP channel.
use std/util "path add"
path add ...([
    ($nu.home-dir | path join ".local" "share" "mise" "shims")
    ($nu.home-dir | path join ".local" "bin")
    ($nu.home-dir | path join ".cargo" "bin")
] | where {|d| $d | path exists })
$env.config.show_banner = false
```

Do not `source` the user autoload from `lsp.nu` unless the user asks:
diagnostics in standalone scripts must not depend on interactive commands.

**Verify:** `nu -c 'print $nu.default-config-dir; print $nu.user-autoload-dirs'`
points at the rendered files; a new Nushell session prints no error; `skh`,
`repo`, `ll`, `z`, the starship prompt, and atuin history work.

---

## 5. Stable binary paths for GUI applications

Alacritty and Zed start natively and do not inherit the mise-activated
environment. They must reference a stable path, not a versioned install path.

Replace `scripts/refresh-mise-fish-link` and `scripts/refresh-mise-deno-link`
with one script, `scripts/refresh-links.nu [tool ...]` (default `nu deno`):

- Resolve the target with `mise which <tool>`; fail clearly if it does not resolve.
- macOS/Linux: symbolic link `~/.local/bin/<tool>`, atomic replacement
  (create `<link>.new`, rename over). Refuse to replace a non-symlink.
- Windows: **hard link** `~/.local/bin/<tool>.exe` with `cmd /c mklink /H`
  (no Developer Mode or elevation needed; same volume). Rename the existing
  file to `.old` first (a running `nu.exe` cannot be overwritten but can be
  renamed), restore it if `mklink` fails, delete `.old` best-effort.
- Hard links are snapshots: the script must run after every upgrade.

Then point every consumer at the stable path:

| Consumer | Setting | Value |
| --- | --- | --- |
| Alacritty | `[terminal.shell] program` | `~/.local/bin/nu` (`nu.exe` on Windows), `args = ["--login"]` only if needed |
| Zed | `terminal.shell.program` | same |
| Zed | `lsp.nu.binary` | same path, `arguments = ["--config", "<config dir>/lsp.nu", "--lsp"]` |
| Helix | `editor.shell` | `["<stable nu>", "-c"]` |
| Helix | `[language-server.nu-lsp]` | `command = "<stable nu>"`, same `args` as Zed |

Render absolute paths in templates with `joinPath .chezmoi.homeDir …`;
do not rely on `~` expansion in application configs.

Remove all WSL paths: the WSL branch of the Alacritty template, any
`fail` on Windows, `scripts/setup-alacritty-wsl-links.ps1`, the
`wsl_distribution` data key and its prompt.

**Verify:** `hx --health nu` shows the language server OK; in Zed, `.nu`
files show diagnostics and the terminal opens Nushell; Alacritty opens
Nushell on every OS.

---

## 6. chezmoi run scripts

### 6.1 Interpreter for `.nu` scripts

- Unix: first line rendered by `.chezmoitemplates/nu-shebang`:
  `#!<home>/.local/share/mise/shims/nu` (absolute, no activation needed).
  The template renders nothing on Windows.
- Windows: in `.chezmoi.toml.tmpl`, only for Windows:
  ```toml
  [interpreters.nu]
  command = "mise"
  args    = ["exec", "--", "nu"]
  ```
  Tell the user to run `chezmoi init` once to regenerate `chezmoi.toml`.

### 6.2 Scripts

| Script | Content | Trigger |
| --- | --- | --- |
| `run_onchange_after_00-mise-install.sh.tmpl` (non-Windows) / `.ps1.tmpl` (Windows) | `mise install` | sha256 of `config.toml` and each `conf.d/*.toml` |
| `run_onchange_after_10-refresh-links.nu.tmpl` | `scripts/refresh-links.nu` | sha256 of mise config + script |
| `run_onchange_after_20-nushell-init.nu.tmpl` | `scripts/nushell-init.nu` | sha256 of mise config + script |
| `run_onchange_after_50-mobile-rust-targets.nu.tmpl` | `rustup target add` (iOS only on macOS) | only when profile `mobile` |

- The install script is the only bash/PowerShell pair: Nushell does not exist
  before it runs. Every later script is Nushell.
- A script whose rendered content is empty is skipped by chezmoi: wrap
  OS-specific scripts in `{{ if … }}` blocks covering the whole file.
- Hash `include`s must reference files that exist on every machine; for
  profile files that may be absent, use `{{ if stat … }}` guards.
- Delete: `run_once_after_10-refresh-mise-fish-link.sh.tmpl`,
  `run_once_after_10-refresh-mise-deno-link.sh.tmpl`,
  `run_onchange_after_50-mobile-rust-targets.sh.tmpl`, and the two old
  `scripts/refresh-mise-*-link` scripts.

### 6.3 First-apply ordering

Templates are rendered **before** any run script. Any template using
`lookPath` on a mise-managed tool (e.g. `rustc-wrapper = "sccache"` in
`~/.cargo/config.toml`) renders the wrong branch on a fresh machine.

- Replace `lookPath` checks for mise-managed tools with unconditional
  configuration, since the tool is declared in the mise config.
- For `rustc-wrapper`, use the absolute mise shim path
  (`<home>/.local/share/mise/shims/sccache`, `.exe` on Windows) so cargo
  finds it from any environment.
- If a tool is genuinely optional, gate it on chezmoi data, not on `lookPath`.

**Verify:** on a clean user profile (or a fresh VM), one `chezmoi init --apply`
produces a working Nushell session with no second apply.

---

## 7. justfile and upgrade workflow

```just
set shell := ["nu", "-c"]
set windows-shell := ["nu", "-c"]
```

Recipes: `default` (`just --list`), `refresh-links`, `nushell-init`,
`doctor`, `upgrade`.

`upgrade` order:
1. Upgrade mise itself **with the method used to install it** (see open
   question Q1). Do not call `mise self-update` unconditionally: it fails or
   conflicts when mise comes from Homebrew, winget, Scoop, or a distro package.
2. `mise upgrade --bump`
3. `mise reshim`
4. `chezmoi re-add ~/.config/mise`
5. `just refresh-links`
6. `just nushell-init`
7. `rustup update`
8. `uv tool upgrade --all` (only if uv is in the mise config)

Do not upgrade Zed, Alacritty, Git, chezmoi from here: they are prerequisites
owned by the OS installer; mention that in the README.

`scripts/doctor.nu` checks: required commands on PATH, `mise doctor` reports
activation, stable links match `mise which` (on Windows compare
`--version` output, hard links have no readable target), each vendor autoload
file exists, global Git ignore exists.

The `system_upgrade` command calls `just --justfile <source>/justfile
--working-directory <source> upgrade`.

---

## 8. Login shell and GUI environment (macOS/Linux)

- Do **not** change the login shell to Nushell. SSH sessions, `sh -c` users,
  and tools that source the login shell expect POSIX syntax. Terminals and
  editors launch Nushell explicitly (Phase 5).
- Zed derives its environment from the login shell. Ensure the login shell
  profile managed by the dotfiles (`~/.zprofile` on macOS, `~/.profile` on
  Linux; create only if missing from the repo, ask before overwriting) adds
  `~/.local/share/mise/shims` and `~/.local/bin` to PATH, so language servers
  started by Zed (rust-analyzer, taplo, etc.) resolve.
- Windows: ensure `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\.local\bin`
  are in the **user** PATH (registry). If missing, add them from the
  PowerShell install script, idempotently.

---

## 9. Retire Fish (after the user confirms)

Only after the user confirms one week of daily use on each OS:

- Delete `dot_config/private_fish/`.
- Remove `aqua:fish-shell/fish-shell` from the mise config.
- Remove the `fish_indent` formatter from `dot_config/helix/languages.toml`.
- Remove `.config/fish` lines from `.chezmoiignore`.

---

## 10. Documentation and final verification

- Update `README.md`: prerequisites (Zed, Alacritty, Git, rustup, chezmoi,
  mise), bootstrap command, per-OS config locations (Phase 3 table), shell
  section Fish → Nushell, upgrade workflow, no WSL.
- Run on each OS: `chezmoi diff`, `chezmoi apply`, `just doctor`,
  `hx --health nu`, open Zed and Alacritty.
- Report to the user: changed files, deleted files, deviations from this
  document, open questions.

---

## Open questions (ask before Phase 2 and Phase 7)

- **Q1.** How is mise installed on each OS (official installer, Homebrew,
  winget/Scoop)? Determines the upgrade command in Phase 7.
- **Q2.** Is `dot_config/mise/config.toml` a template or encrypted?
  Determines Phase 2.5.
- **Q3.** Which crates must stay source-built (and with which features)?
