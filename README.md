# dotfiles

Personal configuration managed with [chezmoi](https://chezmoi.io). One source
tree works natively on **macOS, Linux, and Windows** (no WSL).

- **Nushell** is the interactive shell everywhere. The login shell stays the
  OS default (zsh, bash, PowerShell).
- **mise** installs and pins every CLI tool, Nushell included.
- **rustup** owns the Rust toolchain.
- **just** + Nushell scripts provide the maintenance tasks.

| Owner     | Responsibility                                       |
| --------- | ---------------------------------------------------- |
| chezmoi   | files, templates, externals, run scripts             |
| mise      | CLI tools and their versions                         |
| rustup    | Rust toolchain and components                        |
| Nushell   | interactive shell, personal commands, maintenance scripts |
| just      | entry points for maintenance tasks                   |
| OS shell  | login shell (zsh, bash, PowerShell)                  |

## Contents

- [Before the first `chezmoi apply`](#before-the-first-chezmoi-apply)
- [Profiles](#profiles)
- [Scripts and recipes](#scripts-and-recipes)
- [What is managed](#what-is-managed)
- [Tools](#tools)
- [Nushell](#nushell)
- [Daily workflow](#daily-workflow)
- [Repository layout](#repository-layout)
- [Secrets](#secrets)

## Before the first `chezmoi apply`

The dotfiles never install or upgrade these prerequisites. Everything else,
Nushell included, is installed by mise.

### 1. Prerequisites

| Prerequisite         | Notes                                                       |
| -------------------- | ----------------------------------------------------------- |
| Git                  |                                                             |
| Rust ([rustup])      | on Windows, rustup requires the MSVC Build Tools            |
| chezmoi              | step 2                                                      |
| mise                 | step 2                                                      |
| Zed, Alacritty       | [zed.dev](https://zed.dev), [alacritty.org](https://alacritty.org) |
| FiraCode Nerd Font   | step 3                                                      |
| age key              | step 5                                                      |

[rustup]: https://rustup.rs

On Windows, install the MSVC Build Tools (Visual Studio Build Tools, "Desktop
development with C++") before running rustup.

### 2. mise and chezmoi in `~/.local/bin`

mise as the standalone release binary, chezmoi next to it
(`%USERPROFILE%\.local\bin` on Windows):

```sh
# macOS, Linux
curl -fsSL https://mise.run | sh
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" -- -b ~/.local/bin
```

```powershell
# Windows (PowerShell)
irm https://mise.run/powershell | iex
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b '$HOME\.local\bin'"
```

Make sure `~/.local/bin` is on `PATH` in the current session. On Windows the
mise installer adds it to the user `Path`; the apply scripts also add it.

### 3. FiraCode Nerd Font

Download `FiraCode.zip` from the
[Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases) and
extract it. Then:

- **macOS:** open the `.ttf` files with Font Book and click "Install Font", or
  copy them to `~/Library/Fonts`.
- **Linux:** copy the `.ttf` files to `~/.local/share/fonts`, then run
  `fc-cache -f`.
- **Windows:** select the `.ttf` files, right-click, "Install".

### 4. Rust editor component

```sh
rustup component add rust-analyzer
```

rustup's default profile does not include it. Repeat for every new toolchain.

### 5. age key (profile `poste`)

Place the key at `~/.config/chezmoi/key.txt`. It is required to decrypt the
`*.age` files.

### 6. Apply

- **New machine:** `chezmoi init --apply https://github.com/mocer/dotfiles`
- **Existing machine, after the Nushell migration:** run `chezmoi init` once
  (it adds the Windows interpreter for `.nu` scripts), then `chezmoi apply`.

`chezmoi init` asks once for the [profiles](#profiles) of the machine and, with
`poste`, for the Bedrock inference profile ARNs (empty to skip). Answers are
stored in `~/.config/chezmoi/chezmoi.toml` and reused on every later `init`.

### 7. Login shell

Confirm the login shell is the OS default: zsh on macOS, bash on Linux,
PowerShell on Windows. Nushell is never the login shell; Alacritty, Zed, and
Helix start it explicitly. On macOS and Linux chezmoi manages a minimal login
profile (`~/.zprofile`, `~/.profile`) that puts the mise shims, `~/.local/bin`,
and `~/.cargo/bin` on `PATH` for GUI applications.

### Not managed

SSH keys and `~/.ssh/allowed_signers` are not in this repository. Git signs
commits with SSH and expects `~/.ssh/id_ed25519_developer.pub` and
`~/.ssh/allowed_signers` to exist.

## Profiles

Machine roles, chosen at `chezmoi init` and gated by `.chezmoiignore`. A
machine with no profile gets the base configuration.

| Profile  | Adds                                                                 |
| -------- | -------------------------------------------------------------------- |
| `poste`  | work tools (`conf.d/poste.toml`: `kcli`, OpenShift `oc`), AWS config and Claude Code on Amazon Bedrock, Bedrock and GitHub Enterprise Copilot in Zed, the encrypted `claude-code-with-bedrock` config |
| `mobile` | `conf.d/mobile.toml` (`cargo-ndk`, Java Temurin 21) and the Rust mobile targets (`rustup target add`) |

The Bedrock files (`~/.claude/settings.json`, the Zed Bedrock blocks) render
only when all three ARNs are set.

Machine-local overrides go under `[data]` in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
cargo_jobs = 8               # default: Cargo's own choice
sccache_cache_size = "20G"   # default: 50G
ghr_root = "~/Repos"         # default: ~/Repos
```

## Scripts and recipes

chezmoi runs these automatically after `apply`, only when their inputs change:

| Script                    | What it does                                            |
| ------------------------- | ------------------------------------------------------- |
| `00-mise-install`         | two-pass install (below); on Windows also sets user PATH |
| `10-refresh-links`        | `scripts/refresh-links.nu`: stable links in `~/.local/bin` |
| `20-nushell-init`         | `scripts/nushell-init.nu`: Nushell vendor autoload files |
| `50-mobile-rust-targets`  | `rustup target add` (profile `mobile` only)             |

Two-pass install: first a blocking bootstrap (`nu`, `cargo-binstall`), so
later scripts have Nushell; then a non-blocking `mise install` of everything
else. If a tool fails in the second pass, a warning names it, the remaining
scripts still run, and `just doctor` reports what is missing.

Maintenance recipes (run from the source directory, through Nushell):

| Recipe                    | What it does                                            |
| ------------------------- | ------------------------------------------------------- |
| `just doctor`             | verify tools, links, and the pinned Nushell version     |
| `just refresh-links`      | refresh the stable `~/.local/bin` links                 |
| `just nushell-init`       | regenerate the Nushell vendor autoload files            |
| `just upgrade`            | upgrade mise, chezmoi, tools, Rust, and uv tools; stops if `chezmoi status ~/.config/mise` is not empty |
| `just upgrade-nu <ver>`   | move Nushell to `<ver>`; restores the old version if a check fails |

Nushell is held at the version pinned in `config.toml`: `just upgrade` never
bumps it, only `just upgrade-nu` does. From any directory, `system_upgrade`
(Nushell command) runs `just upgrade` on the source directory.

`just upgrade` in order: `mise self-update`, `chezmoi upgrade`, the mise
config guard, `mise upgrade --bump` (Nushell excluded), `chezmoi re-add
~/.config/mise`, `chezmoi apply`, `rustup update`, `uv tool upgrade --all`.
It ends with `git status --short` of the source directory: commit the bumped
versions yourself.

### Stable links

Native applications (Alacritty, Zed, Cargo) do not see the environment
activated by mise. They use stable links in `~/.local/bin` instead of
versioned install paths: `nu`, `deno`, `sccache`. Symbolic links on macOS and
Linux, hard links (`.exe`) on Windows, refreshed after every install.

## What is managed

Per-OS locations come from one shared template in `.chezmoitemplates/`,
rendered to the path each OS expects.

| Config          | macOS                                 | Linux                | Windows                       |
| --------------- | ------------------------------------- | -------------------- | ----------------------------- |
| Nushell         | `~/Library/Application Support/nushell` | `~/.config/nushell` | `%APPDATA%\nushell`           |
| Alacritty       | `~/.config/alacritty`                 | `~/.config/alacritty` | `%APPDATA%\alacritty`        |
| Zed             | `~/.config/zed`                       | `~/.config/zed`      | `%APPDATA%\Zed`               |
| Helix           | `~/.config/helix`                     | `~/.config/helix`    | `%APPDATA%\helix`             |
| GitHub CLI      | `~/.config/gh`                        | `~/.config/gh`       | `%APPDATA%\GitHub CLI`        |
| mpv             | `~/.config/mpv`                       | `~/.config/mpv`      | `%APPDATA%\mpv`               |
| Login profile   | `~/.zprofile`                         | `~/.profile`         | —                             |

Same path on every OS:

| File                         | Content                                                  |
| ---------------------------- | -------------------------------------------------------- |
| `~/.config/mise/`            | tool versions: `config.toml` and `conf.d/*.toml`         |
| `~/.cargo/config.toml`       | sccache wrapper (stable link), shared `target-dir`, optional `jobs`, `SCCACHE_*` env |
| `~/.gitconfig`               | identity fallback, SSH commit signing, global ignore     |
| `~/.config/git/ignore`       | global Git ignore (OS metadata, editor backups, local env files) |
| `~/Repos/ghr.toml`           | [ghr] profiles: Git identity per host                    |
| `~/.config/starship.toml`    | prompt                                                   |
| `~/.config/atuin/config.toml`| shell history                                            |
| `~/.config/alacritty/themes` | [alacritty-theme] clone (chezmoi external, refreshed weekly) |
| `~/.aws/config`, `~/.claude/settings.json` | profile `poste` only                       |

[ghr]: https://github.com/siketyan/ghr
[alacritty-theme]: https://github.com/alacritty/alacritty-theme

Fish (`~/.config/fish`) is still deployed on macOS and Linux as a legacy
configuration and will be removed.

## Tools

Tools are pinned to explicit versions in `dot_config/mise/config.toml`
(always applied), `conf.d/cargo.toml` (always applied), or a profile file.
Exceptions still on `latest`: `just-lsp`, `ruff`, `ty`,
`docker-language-server`.
Backend policy: registry short name or `aqua:`/`github:` first; `cargo:` only
for crates without release binaries for macOS, Linux, and Windows. Those live
in `conf.d/cargo.toml` and are installed by cargo-binstall, or built from
source when no binary exists.

| Area                 | Tools                                                           |
| -------------------- | --------------------------------------------------------------- |
| Shell                | Nushell, carapace, starship, atuin, zoxide                      |
| Editors and LSPs     | Helix, taplo, markdown-oxide, just-lsp, ruff, ty, docker-language-server |
| Version control      | gh, jj, ghr                                                     |
| Rust workflow        | cargo-binstall, sccache, cargo-nextest, cargo-watch, cargo-audit, cargo-deny, cargo-machete, cargo-about, tarpaulin, cargo-edit, cargo-expand, cargo-cache, sqlx-cli |
| Runtimes             | Deno, Python, uv                                                |
| CLI utilities        | bat, eza, fd, ripgrep, sd, skim, bottom, jaq, yq, xh, ouch, rip2, tokei, hyperfine, grex, git-cliff, usql, usage |
| Task runner          | just                                                            |
| Secrets              | rage, sops                                                      |

Rust itself (and `rust-analyzer`) comes from rustup, never from mise. Zed,
Alacritty, and Git are prerequisites and are not upgraded by the dotfiles.

## Nushell

Load order: `env.nu` → `config.nu` → vendor autoload → `autoload/`.

- `env.nu`: `PATH` (mise shims, `~/.local/bin`, `~/.cargo/bin`, plus OrbStack
  on macOS), `SCCACHE_*` mirrored from `~/.cargo/config.toml`, `GHR_ROOT`,
  locale.
- `config.nu`: settings and aliases (`l`/`ll`/`la`/`lt` for eza, `cat` for
  bat, Cargo `cb`/`ct`/`cw`/…, chezmoi `cza`/`czd`/`czr`/`czs`/…, Jujutsu
  `jl`/`jd`/`jn`/…). `ls` stays the structured built-in.
- Vendor autoload (`$nu.data-dir/vendor/autoload`): mise, starship, zoxide,
  atuin, carapace. Generated by `just nushell-init`, not at every start.
- `autoload/functions.nu`: personal commands.

| Command                | What it does                                              |
| ---------------------- | --------------------------------------------------------- |
| `repo [query]`         | fuzzy-pick a ghr repository and `cd` into it              |
| `skh [dir]`, `skz [dir]` | fuzzy-pick a file and open it in Helix / Zed            |
| `skdc`, `skcc`         | fuzzy-open a file from the chezmoi source / `~/.config`   |
| `skrg <pattern>`       | ripgrep, pick a match, open it in Helix at that line      |
| `repo-dump`            | dump the text files of the current repository into one file |
| `system_upgrade`       | run `just upgrade` on the dotfiles                        |

`lsp.nu` is the Nushell language server entry point used by Helix and Zed.

## Daily workflow

```nu
# after editing a real file
chezmoi re-add <file>

# after editing the source
chezmoi edit <file>
chezmoi apply

# review before applying
chezmoi diff
chezmoi status

# upgrade everything (Nushell held)
system_upgrade

# commit (source lives in ~/Repos/github.com/mocer/dotfiles)
repo dotfiles
git add .; git commit -m "..."; git push
```

Zed rewrites its settings file when settings change from the UI: run
`chezmoi diff` and bring the changes back into
`.chezmoitemplates/zed/settings.json`.

## Repository layout

```
.
├── .chezmoi.toml.tmpl          # init prompts (profiles, Bedrock ARNs), age, Windows nu interpreter
├── .chezmoidata.toml           # shared defaults (locale, sccache size, ghr root, profiles)
├── .chezmoidata/               # bedrock.toml, mpv.toml
├── .chezmoiexternal.toml.tmpl  # alacritty-theme clone
├── .chezmoiignore              # profile and per-OS gating
├── .chezmoiscripts/            # run_onchange install, links, Nushell init, mobile targets
├── .chezmoitemplates/          # shared templates: nushell, alacritty, zed, helix, gh, mpv, helpers
├── AppData/Roaming/            # Windows targets (include the shared templates)
├── Library/Application Support/# macOS Nushell target
├── dot_config/                 # ~/.config: mise, nushell, alacritty, zed, helix, gh, mpv, git, atuin, starship
├── dot_cargo/                  # ~/.cargo/config.toml
├── dot_aws/, dot_claude/       # profile poste
├── claude-code-with-bedrock/   # encrypted company config (profile poste)
├── Repos/ghr.toml              # ghr profiles
├── dot_gitconfig, dot_zprofile, dot_profile
├── scripts/                    # Nushell maintenance scripts (not deployed)
├── justfile                    # maintenance recipes (not deployed)
└── docs/                       # migration runbook (not deployed)
```

`scripts/`, `justfile`, `docs/`, and `README.md` stay in the source directory
and are never deployed.

## Secrets

- Encrypted files use age (`chezmoi add --encrypt`), decrypted with
  `~/.config/chezmoi/key.txt`. Never edit `*.age` files by hand.
- Private SSH keys, tokens, and the Bedrock ARNs are never committed. The ARNs
  live in the machine-local `~/.config/chezmoi/chezmoi.toml`.
