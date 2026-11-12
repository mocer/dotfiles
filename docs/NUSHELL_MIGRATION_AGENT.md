# Fish → Nushell migration: agent runbook

## Contents

1. [Context and rules](#1-context-and-rules)
2. [Inputs](#2-inputs)
3. [Decisions log](#3-decisions-log)
4. [Phase 1 — Repository hygiene](#4-phase-1--repository-hygiene)
5. [Phase 2 — mise tool set](#5-phase-2--mise-tool-set)
6. [Phase 3 — Per-OS configuration paths](#6-phase-3--per-os-configuration-paths)
7. [Phase 4 — Nushell configuration](#7-phase-4--nushell-configuration)
8. [Phase 5 — Stable binary links](#8-phase-5--stable-binary-links)
9. [Phase 6 — Terminal and editors](#9-phase-6--terminal-and-editors)
10. [Phase 7 — Cargo and sccache](#10-phase-7--cargo-and-sccache)
11. [Phase 8 — chezmoi run scripts](#11-phase-8--chezmoi-run-scripts)
12. [Phase 9 — justfile and upgrade workflow](#12-phase-9--justfile-and-upgrade-workflow)
13. [Phase 10 — Login shell and GUI environment](#13-phase-10--login-shell-and-gui-environment)
14. [Phase 11 — README: prerequisites and first apply](#14-phase-11--readme-prerequisites-and-first-apply)
15. [Phase 12 — Remove Fish](#15-phase-12--remove-fish)
16. [Final verification and report](#16-final-verification-and-report)
17. [Out of scope (later work)](#17-out-of-scope-later-work)

---

## 1. Context and rules

The dotfiles repository (`~/Repos/github.com/mocer/dotfiles`, the chezmoi
source directory) moves from Fish to Nushell. The same source tree must work
**natively** on macOS, Linux, and Windows. **WSL2 is out of scope**: remove
every WSL code path. Work happens on branch `develop`; `master` keeps the
old configuration and is never touched.

Prerequisites, installed by the user before the first `chezmoi apply` and
never installed or upgraded by the dotfiles:

| Prerequisite | Notes |
| --- | --- |
| Git | |
| Rust (rustup) | on Windows, rustup requires the MSVC Build Tools |
| chezmoi | |
| mise | standalone release binary in `~/.local/bin` |
| Zed, Alacritty | |
| FiraCode Nerd Font | installation is OS-specific |
| age key | `~/.config/chezmoi/key.txt`, required for encrypted files |

Everything else, Nushell included, is installed by mise.

Responsibilities stay separate:

| Owner | Responsibility |
| --- | --- |
| chezmoi | files, templates, externals, run scripts |
| mise | CLI tools and their versions |
| rustup | Rust toolchain and components |
| Nushell | interactive shell, personal commands, maintenance scripts |
| just | entry points for maintenance tasks |
| OS default shell | login shell (zsh, bash, PowerShell) |

Rules:

1. **Inspect before editing.** Confirm each file exists and matches the
   description here. If it differs, follow the intent of the step and record
   the difference for the final report. Never invent files or settings.
2. **One phase at a time.** Run the phase verification, then commit on
   `develop` with a message naming the phase, and wait for the user's "ok".
3. **No new tools** except those named in this document.
4. English comments and docs; direct style, consistent with the repository.
5. Never print secrets. Never decrypt, re-encrypt, or edit `*.age` files.
6. **Stop and ask the user** whenever a step says so, or when a step conflicts
   with what you find.
7. Never revisit an entry of the [Decisions log](#3-decisions-log).
8. Do not touch anything listed in [Out of scope](#17-out-of-scope-later-work).

## 2. Inputs

- The dotfiles repository (the current working directory).
- A first draft of the Nushell files, produced earlier. Part of it is already
  in the repository: `dot_config/nushell/config.nu`,
  `dot_config/nushell/env.nu.tmpl`, `dot_config/nushell/autoload/functions.nu`.
  The rest (`scripts/*.nu`, `.chezmoiscripts/*`, `.chezmoitemplates/nu-shebang`,
  `justfile`, `.chezmoi.toml.tmpl` changes) may be missing: check with
  `git status` and `ls -a`, and report what is missing. If the user provides
  the draft folder, reuse its content where this runbook says so. This
  runbook takes precedence wherever they differ; in particular the draft's
  `symlink_nushell.tmpl` files, the WSL assumptions in `refresh-links.nu`,
  and the old `MIGRATION.md` are superseded.

## 3. Decisions log

Decisions already taken with the user. Do not revisit them.

| Topic | Decision |
| --- | --- |
| Platforms | macOS, Linux, Windows, all native. No WSL2. |
| Branches | Work on `develop`. Never checkout, merge, rebase, or push `master`. |
| Backends | Registry short name or `aqua:`/`github:` first. `cargo:` only for crates without release assets for macOS, Linux, and Windows. Performance is identical across backends. |
| Cargo tools | Every `cargo:` tool lives in `dot_config/mise/conf.d/cargo.toml`, always applied. It is **not** a chezmoi profile. Exceptions: `kcli` stays in `poste.toml`, `cargo-ndk` stays in `mobile.toml`. |
| Profiles | `poste`, `mobile`: machine roles chosen at `chezmoi init`, gated by `.chezmoiignore`. |
| Install order | mise installs cargo-binstall before `cargo:` tools by itself: no ordering workaround. |
| First install | Two passes: blocking bootstrap (`nu`, `cargo-binstall`), then non-blocking full install (Phase 8). |
| Nushell version | Pinned to `0.117.0`. Held: never bumped by `just upgrade`; changed only with `just upgrade-nu`. |
| minimum_release_age | Never bypassed. If a pinned version is not yet installable, keep the pin and report it. |
| Versions | Every tool pinned to an explicit version; no `latest`. |
| mise | Standalone binary in `~/.local/bin`, upgraded with `mise self-update`. `self_update.auto` stays off. |
| chezmoi | Standalone binary in `~/.local/bin`, upgraded with `chezmoi upgrade` by `just upgrade`. |
| Rust | Managed by rustup only; never declared in mise. `rust-analyzer` is a manual README step. |
| Alacritty themes | chezmoi external `git-repo` clone of `alacritty-theme`. |
| Login shell | OS default (zsh, bash, PowerShell). Nushell is never the login shell. |
| Git ignore | No repository `.gitignore`: `core.excludesFile` points to `dot_config/git/ignore`. |
| Fish | `dot_config/private_fish/` untouched until the user explicitly asks for Phase 12. |
| sccache | Stable link `~/.local/bin/sccache`; `dot_config/sccache/config.tmpl` is deleted. |

---

## 4. Phase 1 — Repository hygiene

On Windows, Git may convert files to CRLF. A `.nu` script or a shebang line
with CRLF breaks on Unix.

1. Create `.gitattributes`:
   ```gitattributes
   * text=auto eol=lf
   *.ps1 text eol=crlf
   *.age binary
   ```
2. `dot_config/mise/.DS_Store` is tracked by mistake: `git rm --cached` it,
   and add `.DS_Store` to `.chezmoiignore`; Git ignores it through the
   global excludes file (`dot_config/git/ignore`).
3. Add `.gitattributes` and `docs/**` to the
   "Repository-only files" block of `.chezmoiignore`.
4. Run `git add --renormalize .` and commit on its own.

**Verify:** `git ls-files --eol | rg 'w/crlf'` lists only `.ps1` files;
`git ls-files | rg DS_Store` is empty.

---

## 5. Phase 2 — mise tool set

> Status: first pass done in commit `f842458`. Apply the amendments marked
> **(amend)** below, show the diff, and commit.

Files: `dot_config/mise/config.toml`, `dot_config/mise/conf.d/*.toml`. All
plain TOML, never templates or encrypted: `chezmoi re-add` must be able to
sync `mise upgrade --bump` changes back.

### 2.1 Backend policy

Performance is identical across backends: cargo-binstall and aqua download
the same author-published release, and a local `cargo install` without
`RUSTFLAGS` produces an equivalent binary. Choose the backend for install
reliability, and make the result identical on every OS:

- prefer the registry short name (`mise registry <tool>`);
- use an explicit `aqua:`/`github:` identifier only when the short name is
  missing or resolves to `cargo:`;
- keep `cargo:` only for crates without release binaries for **all three**
  OSes (macOS arm64, Linux x64, Windows x64);
- `cargo-binstall` and `nu` are always prebuilt (aqua);
- no "OPTIMIZED TOOLS (Forced Compilation)" section, no `features` /
  `default-features` options, no `RUSTFLAGS` comments.

### 2.2 Files

1. **(amend)** Create `dot_config/mise/conf.d/cargo.toml` and move into it
   every tool that stays on `cargo:` in `config.toml` (expected: cargo-cache,
   cargo-edit, cargo-expand, sqlx-cli, tokei, eza, ghr). Header comment:
   ```toml
   # Tools without prebuilt releases for all three OSes.
   # Installed by cargo-binstall when a release exists, otherwise built from
   # source with `cargo install` (Windows needs the MSVC Build Tools).
   # Always applied: this is not a chezmoi profile.
   ```
   No `.chezmoiignore` entry for this file.
2. **(amend)** Nushell: `"aqua:nushell/nushell" = "0.117.0"`. Do not bypass
   `minimum_release_age`: if 0.117.0 does not resolve yet, keep the pin and
   report it.
3. **(amend)** `cargo-ndk` in `mobile.toml`: replace `latest` with the
   current latest version.
4. `kcli` stays in `poste.toml` on `cargo:`.
5. carapace added (registry short name).
6. `aqua:fish-shell/fish-shell` stays until Phase 12.

**Verify:**
- `mise ls --missing` parses all files without errors (missing tools are
  expected until the user approves `mise install`);
- `rg '^"cargo:' dot_config/mise/config.toml` is empty;
- after the user approves `mise install`: `mise which nu`,
  `mise which carapace`, `mise which cargo-binstall` resolve,
  `nu --version` prints `0.117.0`, `rg --pcre2-version` reports PCRE2.

Report a table: tool, old backend, new backend, OSes without a release asset.

---

## 6. Phase 3 — Per-OS configuration paths

Several applications do not read `~/.config` on every OS. Do **not** use
chezmoi `symlink_` entries: on Windows they need Developer Mode or elevation.
Render one shared template at the path each application reads.

| Application | macOS | Linux | Windows |
| --- | --- | --- | --- |
| Nushell | `~/Library/Application Support/nushell` | `~/.config/nushell` | `%APPDATA%\nushell` |
| Alacritty | `~/.config/alacritty` | `~/.config/alacritty` | `%APPDATA%\alacritty` |
| Zed | `~/.config/zed` | `~/.config/zed` | `%APPDATA%\Zed` |
| Helix | `~/.config/helix` | `~/.config/helix` | `%APPDATA%\helix` |
| gh | `~/.config/gh` | `~/.config/gh` | `%APPDATA%\GitHub CLI` |
| mpv | `~/.config/mpv` | `~/.config/mpv` | `%APPDATA%\mpv` |

Same path on every OS (leave as is): mise, starship, atuin, git, chezmoi,
`~/.cargo`, `~/.aws`, `~/.claude`.

Before moving anything, confirm each path from the application itself
(`nu -c '$nu.default-config-dir'`, `hx --health` header, official docs).
Record any difference.

Pattern for each application in the table:

1. Move the content to `.chezmoitemplates/<app>/<file>`
   (e.g. `.chezmoitemplates/nushell/config.nu`). Files in
   `.chezmoitemplates` are always templates: no `.tmpl` suffix.
2. Create one thin file per location, containing only
   `{{ template "<app>/<file>" . }}`:
   - `dot_config/<app>/<file>.tmpl`
   - `Library/Application Support/<app>/<file>.tmpl` (Nushell only)
   - `AppData/Roaming/<WindowsDir>/<file>.tmpl`
   Keep existing attributes (`private_`) on the thin files.
3. Rewrite the OS block of `.chezmoiignore`:
   ```
   {{ if ne .chezmoi.os "darwin" -}}
   Library
   {{ end -}}
   {{ if ne .chezmoi.os "windows" -}}
   AppData
   {{ end -}}
   {{ if eq .chezmoi.os "darwin" -}}
   .config/nushell
   {{ end -}}
   {{ if eq .chezmoi.os "windows" -}}
   .config/nushell
   .config/alacritty
   .config/zed
   .config/helix
   .config/gh
   .config/mpv
   .config/fish
   {{ end -}}
   ```
   `.config/fish` is ignored on Windows only until Phase 12: its
   `symlink_*.fish` files would make `chezmoi apply` fail there.
4. Delete the draft files `Library/Application Support/symlink_nushell.tmpl`
   and `AppData/Roaming/symlink_nushell.tmpl` if present.

**Verify:** `chezmoi managed | rg -i "nushell|alacritty|zed|helix|gh|mpv"`
shows exactly one location per application; `chezmoi diff` shows no content
change for the moved files on the current OS.

---

## 7. Phase 4 — Nushell configuration

Target: Nushell **0.117.0**. Write only syntax valid for that version.

Reuse the draft files, rendered through the Phase 3 pattern:

| File | Content |
| --- | --- |
| `env.nu` | PATH and environment variables only |
| `config.nu` | `$env.config`, aliases, greeting |
| `autoload/functions.nu` | personal commands |
| `lsp.nu` | minimal configuration for `nu --lsp` (new, below) |

Load order: `env.nu` → `config.nu` → vendor autoload → user `autoload/`.

Required corrections to the draft:

1. `config.nu`: the greeting becomes `if $nu.is-interactive { print "…" }`.
2. `env.nu`: OrbStack is macOS only. Keep `~/.orbstack/bin` on PATH, rendered
   only on macOS. Port the rest of the OrbStack Fish integration only if
   `~/.orbstack/shell/` ships a Nushell init file; otherwise drop it.
3. `env.nu`: `GHR_ROOT` must be computed exactly as Fish did
   (`.ghr_root` with `~` expanded).
4. `env.nu`: render the mise shims path per OS
   (`~/.local/share/mise/shims`; Windows `%LOCALAPPDATA%\mise\shims`).
5. `ghr shell` supports only bash and fish: no Nushell integration. `repo`
   covers navigation.
6. Fish completion files are not ported: command signatures cover personal
   commands, carapace covers external ones.

New file `.chezmoitemplates/nushell/lsp.nu` (rendered next to `config.nu`):

```nu
# Minimal configuration for `nu --lsp` (Zed and Helix).
# Must never print: stdout is the LSP channel.
use std/util "path add"

path add ...([
    <mise shims path, same template expression as env.nu>
    ($nu.home-dir | path join ".local" "bin")
    ($nu.home-dir | path join ".cargo" "bin")
] | where {|d| $d | path exists })

$env.config.show_banner = false
```

Vendor autoload generator: reuse the draft `scripts/nushell-init.nu`
(mise, starship, zoxide, atuin, carapace; a missing tool removes its file
instead of failing).

**Verify:** `nu -c '$nu.default-config-dir'` and
`nu -c '$nu.user-autoload-dirs'` point at the rendered files; every `.nu`
file passes `nu --ide-check 100 <file>` without errors (if that flag does not
exist in 0.117.0, report it and propose an alternative); a new session
starts without errors; `ll`, `z`, `skh`, `repo`, the starship prompt, and
the atuin history key work.

**On Windows (when available):** check `sk` interactively and inside
`skh`/`repo`; its preview runs through `cmd`. Report any failure, do not
work around it.

---

## 8. Phase 5 — Stable binary links

GUI applications (Alacritty, Zed, IINA) and Cargo need paths that survive
upgrades. Replace `scripts/refresh-mise-fish-link` and
`scripts/refresh-mise-deno-link` with `scripts/refresh-links.nu`, taking the
Windows-aware version of the draft (symbolic links on Unix, hard links via
`mklink /H` on Windows), with these changes:

- Default tools: `["nu" "deno" "sccache"]`.
- Remove every reference to WSL from comments.

Resulting paths: `~/.local/bin/<tool>` on Unix,
`%USERPROFILE%\.local\bin\<tool>.exe` on Windows.

Hard links are snapshots: the script must run after every upgrade
(Phase 8 and Phase 9 handle this).

**User action (report it, do not do it):** the manual link
`~/.cargo/bin/sccache → ~/.local/share/mise/shims/sccache` becomes
redundant after Phase 7; `~/.cargo/bin` belongs to rustup.

**Verify:** `ls -l ~/.local/bin/{nu,deno,sccache}` point at
`mise which <tool>`.

---

## 9. Phase 6 — Terminal and editors

Use the stable path from Phase 5 everywhere. In templates:

```
{{- $nu := joinPath .chezmoi.homeDir ".local" "bin" (ternary "nu.exe" "nu" (eq .chezmoi.os "windows")) -}}
```

`$lsp` below is the rendered path of `lsp.nu` for the current OS
(Phase 3 table).

### Alacritty

1. Remove the whole WSL branch, `$isWSL`, the `windows_profile` and
   `wsl_distribution` references, and the `fail` for Windows. Remove
   `wsl_distribution` from the chezmoi data and prompts.
2. `[terminal.shell] program = {{ $nu | toJson }}` on every OS.
3. `working_directory = {{ .chezmoi.homeDir | toJson }}` on every OS.
4. Delete `scripts/setup-alacritty-wsl-links.ps1`.

### Alacritty themes

Create `.chezmoiexternal.toml.tmpl` (Git is a prerequisite; no script):

```toml
{{- $dir := ternary "AppData/Roaming/alacritty/themes" ".config/alacritty/themes" (eq .chezmoi.os "windows") }}
# Alacritty color schemes, cloned with Git and refreshed weekly.
[{{ $dir | quote }}]
type = "git-repo"
url = "https://github.com/alacritty/alacritty-theme.git"
refreshPeriod = "168h"

[{{ $dir | quote }}.pull]
args = ["--ff-only"]
```

In the Alacritty template, render the import as an absolute path:
`<alacritty config dir>/themes/themes/enfocado_dark.toml` (the repository
keeps its schemes in a `themes/` subdirectory). `.chezmoiexternal.toml.tmpl`
is a chezmoi special file: do not add it to `.chezmoiignore`.

### Zed

1. Remove the `ne .chezmoi.os "windows"` guard around `terminal`;
   `terminal.shell.program = {{ $nu | toJson }}`.
2. Add the Nushell language server under `lsp`:
   ```json
   "nu": {
     "binary": {
       "path": {{ $nu | toJson }},
       "arguments": ["--config", {{ $lsp | toJson }}, "--lsp"],
     },
   },
   ```
3. Do not change `cargo.targetDir`: the user already fixed it.

### Helix (minimal changes only)

1. `config.toml`: `shell = [{{ $nu | toJson }}, "-c"]`; fix the comment.
2. `languages.toml` (now a template for the paths):
   ```toml
   [language-server.nu-lsp]
   command = {{ $nu | toJson }}
   args = ["--config", {{ $lsp | toJson }}, "--lsp"]
   ```

**Verify:** `hx --health nu` reports the language server OK; in Zed, `.nu`
files show diagnostics and the terminal opens Nushell; Alacritty opens
Nushell with the theme applied; `chezmoi apply` clones the themes.

---

## 10. Phase 7 — Cargo and sccache

### `dot_cargo/config.toml.tmpl`

1. Remove the `[registries]` block (`registries.crates-io.protocol`): the key
   is misspelled and sparse is the default since Rust 1.70.
2. Fix the header comment: the file renders to `~/.cargo/config.toml`.
3. Replace the `lookPath "sccache"` condition with the stable link,
   unconditionally:
   ```toml
   rustc-wrapper = {{ joinPath .chezmoi.homeDir ".local" "bin" (ternary "sccache.exe" "sccache" (eq .chezmoi.os "windows")) | toJson }}
   ```
   Use `toJson` for every path in this file (Windows backslashes).

### sccache configuration

Delete `dot_config/sccache/config.tmpl`. The single source of truth is
`[env]` in `~/.cargo/config.toml`, mirrored by `env.nu`.

**Verify:** `cargo build` in any project uses sccache
(`sccache --show-stats` counts requests).

---

## 11. Phase 8 — chezmoi run scripts

| Script | Content | Trigger |
| --- | --- | --- |
| `run_onchange_after_00-mise-install.sh.tmpl` (non-Windows) | two-pass install (below) | hashes of `config.toml` and every `conf.d/*.toml` |
| `run_onchange_after_00-mise-install.ps1.tmpl` (Windows) | user PATH setup, then two-pass install | same |
| `run_onchange_after_10-refresh-links.nu.tmpl` | `scripts/refresh-links.nu` | mise config + script hash |
| `run_onchange_after_20-nushell-init.nu.tmpl` | `scripts/nushell-init.nu` | mise config + script hash |
| `run_onchange_after_50-mobile-rust-targets.nu.tmpl` | `rustup target add` | `mobile` profile only |

### Two-pass install

1. **Bootstrap pass (blocking):**
   `mise install aqua:nushell/nushell aqua:cargo-bins/cargo-binstall`.
   Every later script needs `nu`. Failure stops `chezmoi apply`.
   The identifiers must match the keys in `config.toml`.
2. **Full pass (non-blocking):** `mise install`. It covers `config.toml` and
   every active `conf.d` file (cargo tools, profiles). On failure, print a
   warning naming the failed tools and exit 0, so links and Nushell init
   still run. `just doctor` reports what is missing.

Hash `include`s must reference files that exist on every machine; for
profile files that may be absent, guard with `stat`.

### Other changes

1. `10-refresh-links` runs on every OS (no Windows guard).
2. `00-mise-install.ps1`: before the install passes, add idempotently to the
   **user** PATH (registry, `[Environment]::SetEnvironmentVariable(…, "User")`)
   `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\.local\bin`, without
   duplicates. Windows GUI applications only see the registry PATH.
3. Windows interpreter for `.nu` scripts: `[interpreters.nu]` in
   `.chezmoi.toml.tmpl` (`command = "mise"`, `args = ["exec", "--", "nu"]`),
   Windows only. Unix uses the shebang from `.chezmoitemplates/nu-shebang`.
4. No script for rustup components: `rust-analyzer` is a README step.
5. Delete `run_once_after_10-refresh-mise-fish-link.sh.tmpl`,
   `run_once_after_10-refresh-mise-deno-link.sh.tmpl`,
   `run_onchange_after_50-mobile-rust-targets.sh.tmpl`, and the two
   `scripts/refresh-mise-*-link` files.

**Verify:** on a clean user profile (or a fresh VM), with the README
prerequisites done, one `chezmoi init --apply` produces a working Nushell
session, editors, and Cargo wrapper, with no second apply. Simulate a failing
tool in the full pass and confirm the later scripts still run.

---

## 12. Phase 9 — justfile and upgrade workflow

```just
set shell := ["nu", "-c"]
set windows-shell := ["nu", "-c"]
```

Multi-line logic goes to scripts. Recipes: `default`, `refresh-links`,
`nushell-init`, `doctor`, `upgrade`, `upgrade-nu <version>`.

### `scripts/upgrade.nu`

```nu
const HELD = ["aqua:nushell/nushell"]  # never bumped automatically
```

Order:

1. `mise self-update -y`; on failure print a warning and continue.
2. `chezmoi upgrade`; on failure print a warning and continue (package-manager
   installs refuse self-upgrade).
3. Upgrade every configured tool except `HELD`: read the configured tool
   names (`mise ls --current --json`), remove `HELD`, pass the rest to
   `mise upgrade --bump`. Confirm the JSON keys match the identifiers
   `mise upgrade` accepts; if not, report and propose an alternative.
4. `chezmoi re-add ~/.config/mise`.
5. `chezmoi apply`: the `run_onchange` scripts (mise install, refresh-links,
   nushell-init) re-run because the mise config hash changed. `upgrade.nu`
   does not call them directly, nor `mise reshim` (`mise install` maintains
   the shims).
6. `rustup update`.
7. `uv tool upgrade --all`.
8. Print `git -C <source> status --short`, so the user sees what to commit.

Do not upgrade Zed, Alacritty, or Git: they are prerequisites.

### `scripts/upgrade-nu.nu <version>`

1. Save the current Nushell version from `config.toml`.
2. Set `"aqua:nushell/nushell"` to `<version>`; `mise install`.
3. Check every repository `.nu` file with `nu --ide-check 100 <file>`, then
   run `just doctor`.
4. On any error, restore the saved version, `mise install`, and fail.
5. On success: `chezmoi re-add ~/.config/mise`, then `chezmoi apply` (the
   `run_onchange` scripts regenerate the vendor autoload). The link refresh
   stays inside `use-version`: the doctor needs it before the apply.

### `scripts/doctor.nu`

Windows-aware version of the draft, plus: `sccache` in the link checks;
`rust-analyzer --version` must run (hint: `rustup component add
rust-analyzer`; the `~/.cargo/bin` proxy exists even without the component);
`nu --version` equals the pinned version.

`system_upgrade` in `functions.nu` calls the `upgrade` recipe.

**Verify:** `just --list`, `just doctor`, `just upgrade` succeed and leave
Nushell at the pinned version.

---

## 13. Phase 10 — Login shell and GUI environment

The login shell stays the OS default: **zsh** on macOS, **bash** on Linux,
**PowerShell** on Windows. Alacritty, Zed, and Helix start Nushell
explicitly. Claude Code's Bash tool also runs in the login shell.

1. Read the login shell: `dscl . -read ~ UserShell` (macOS),
   `getent passwd $USER` (Linux). Report it.
2. If it is Fish, **stop and ask** the user to change it.
3. Zed on macOS and Linux reads its environment from the login shell. Manage
   a minimal login profile: `dot_zprofile` on macOS, `dot_profile` on Linux
   (gate each by OS in `.chezmoiignore`). If the target file already exists,
   compare it and ask before replacing it.
   ```sh
   # Managed by chezmoi: PATH for GUI applications started from the login session.
   export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
   ```
4. Windows is covered by Phase 8. Do not manage a PowerShell profile.

**Verify:** `zsh -lc 'command -v mise chezmoi nu just'` resolves all four;
after logging out and in, Zed's language server log shows no "not
installed" errors for `nu`, `rust-analyzer`, `taplo`.

---

## 14. Phase 11 — README: prerequisites and first apply

The full README rewrite happens after the migration. In this phase, replace
only the installation part with a section **"Before the first
`chezmoi apply`"**, per OS, in this order:

1. Install the prerequisites ([section 1](#1-context-and-rules)), including
   the MSVC Build Tools on Windows as a rustup requirement.
2. Install mise as the standalone release binary and chezmoi, both into
   `~/.local/bin` (`%USERPROFILE%\.local\bin` on Windows), with the official
   commands. Take URLs from the official documentation; never invent them.
3. Install FiraCode Nerd Font with the OS-native method.
4. Add the Rust editor component:
   ```sh
   rustup component add rust-analyzer
   ```
   rustup's default profile does not include it; repeat for every new
   toolchain.
5. Place the age key at `~/.config/chezmoi/key.txt` (profile `poste`).
6. New machine: `chezmoi init --apply <repo>`. Existing machine: `chezmoi
   init` once after this migration (Windows interpreter for `.nu` scripts),
   then `chezmoi apply`.
7. Confirm the login shell is the OS default.

Add a **"Scripts"** subsection: what chezmoi runs automatically (Phase 8
table, including the two-pass install) and the `just` recipes, with
`upgrade-nu` explained (Nushell is held).

---

## 15. Phase 12 — Remove Fish

Run **only when the user explicitly asks for it**, after Phase 10 confirms
the login shell is not Fish and every previous verification passed.

1. Delete `dot_config/private_fish/`.
2. Remove `aqua:fish-shell/fish-shell` from `config.toml`.
3. Remove the Fish formatter and language entry from `languages.toml`.
4. Remove `.config/fish` from `.chezmoiignore`.
5. `rg -i fish` over the repository: remove every remaining reference.
6. Tell the user to run `mise prune` and delete `~/.config/fish` manually.

**Verify:** `rg -i fish` returns nothing relevant; `chezmoi apply` and
`just doctor` succeed.

---

## 16. Final verification and report

On each available OS: `chezmoi init`, `chezmoi diff`, `chezmoi apply`,
`just doctor`, `hx --health nu`, open Zed and Alacritty. Windows checks that
cannot run on the current machine are marked "pending on Windows".

Report to the user:

1. Files changed, created, deleted.
2. Differences between this runbook and what you found.
3. Tools that failed to install, per OS.
4. Pending user actions: remove `~/.cargo/bin/sccache`, run `chezmoi init`,
   install Nushell 0.117.0 if `minimum_release_age` blocked it.

---

## 17. Out of scope (later work)

Do not change these; list related problems in the report.

| Topic | Note |
| --- | --- |
| Docker on Linux and Windows | OrbStack stays macOS only; Windows needs Docker Desktop for buildx |
| Helix | general rework, including JSON/YAML language servers and rust-analyzer `check` settings |
| README | full rewrite to the current state (only Phase 11 is in scope) |
