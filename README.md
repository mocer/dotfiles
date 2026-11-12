Personal configuration files managed with [chezmoi](https://chezmoi.io),
targeting multiple OS. Profiles for multiple identities (personal and work) are
handled transparently via [ghr](https://github.com/nicholasgasior/ghr).

## Before the first `chezmoi apply`

The dotfiles never install or upgrade these prerequisites. Everything else,
Nushell included, is installed by mise. macOS, Linux, and Windows are
supported natively (no WSL).

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

- **macOS:** `brew install --cask font-fira-code-nerd-font`
- **Linux:** download `FiraCode.zip` from the
  [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases),
  extract into `~/.local/share/fonts`, run `fc-cache -f`.
- **Windows:** download the same `FiraCode.zip`, select the `.ttf` files,
  right-click, "Install for all users" or "Install".

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

### 7. Login shell

Confirm the login shell is the OS default: zsh on macOS, bash on Linux,
PowerShell on Windows. Nushell is never the login shell; Alacritty, Zed, and
Helix start it explicitly. On macOS and Linux chezmoi manages a minimal login
profile (`~/.zprofile`, `~/.profile`) that puts the mise shims, `~/.local/bin`,
and `~/.cargo/bin` on `PATH` for GUI applications.

### Scripts

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
bumps it, only `just upgrade-nu` does.

## Managed Tools

### Shell

| Tool                                            | Description                                            |
| ----------------------------------------------- | ------------------------------------------------------ |
| [Fish](https://fishshell.com)                   | Primary shell — PATH, env vars, aliases, abbreviations |
| [Starship](https://starship.rs)                 | Minimal, fast cross-shell prompt                       |
| [Atuin](https://atuin.sh)                       | SQLite-backed shell history sync and search            |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` replacement                                 |
| [Direnv](https://direnv.net)                    | Per-directory environment variable management          |

### Version Control

| Tool                                         | Description                                       |
| -------------------------------------------- | ------------------------------------------------- |
| [Git](https://git-scm.com)                   | Global config, SSH signing, allowed signers       |
| [gh](https://cli.github.com)                 | GitHub CLI configuration                          |
| [ghr](https://github.com/nicholasgasior/ghr) | Multi-profile and multi-host Git identity manager |
| [jj](https://martinvonz.github.io/jj)        | Jujutsu — next-generation Git-compatible VCS      |
| SSH                                          | `~/.ssh/config`, public keys, `allowed_signers`   |

### Development Environment

| Tool                                            | Description                                     |
| ----------------------------------------------- | ----------------------------------------------- |
| [mise](https://mise.jdx.dev)                    | Polyglot runtime and tool version manager       |
| [Cargo / Rust](https://doc.rust-lang.org/cargo) | Sparse registry, sccache wrapper, target triple |
| [sccache](https://github.com/mozilla/sccache)   | Compiler cache — path and size configuration    |
| [rustup](https://rustup.rs)                     | Rust toolchain manager settings                 |
| [uv](https://github.com/astral-sh/uv)           | Fast Python package and project manager         |
| [Deno](https://deno.com)                        | Secure TypeScript/JavaScript runtime            |

### Editors

| Tool                              | Description                                         |
| --------------------------------- | --------------------------------------------------- |
| [Helix](https://helix-editor.com) | Modal editor — keybindings, theme, language servers |
| [Zed](https://zed.dev)            | High-performance collaborative editor               |

### Terminal

| Tool                                             | Description                                              |
| ------------------------------------------------ | -------------------------------------------------------- |
| [Alacritty](https://alacritty.org)               | GPU-accelerated terminal emulator                        |
| [bat](https://github.com/sharkdp/bat)            | `cat` replacement with syntax highlighting and man pager |
| [eza](https://eza.rocks)                         | Modern `ls` replacement                                  |
| [bottom](https://github.com/ClementTsang/bottom) | Cross-platform graphical process monitor                 |

### Productivity & Search

| Tool                                             | Description                                       |
| ------------------------------------------------ | ------------------------------------------------- |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast line-oriented search                         |
| [fd](https://github.com/sharkdp/fd)              | Fast and user-friendly `find` alternative         |
| [skim](https://github.com/lotabout/skim)         | Fuzzy finder — used by `repo` function and zoxide |
| [just](https://just.systems)                     | Command runner and task organizer                 |

### Secrets & Security

| Tool                                  | Description                         |
| ------------------------------------- | ----------------------------------- |
| [rage](https://github.com/str4d/rage) | Modern file encryption (age format) |

> **Note:** Private SSH keys and OAuth tokens are never committed to this
> repository. Sensitive files are either encrypted via `chezmoi add --encrypt`
> or excluded entirely.

## Daily Workflow

```fish
# after editing a real file
chezmoi re-add <file>

# after editing the source directly
chezmoi edit <file>
chezmoi apply

# review before applying
chezmoi diff
chezmoi status

# commit changes (repo lives in ~/Repos/github.com/mocer/dotfiles)
repo dotfiles
git add . && git commit -m "..." && git push
```

## Structure

```
~/.local/share/chezmoi/   # or ~/Repos/github.com/mocer/dotfiles
├── dot_gitconfig
├── dot_config/
│   ├── fish/
│   ├── helix/
│   ├── mise/
│   ├── cargo/
│   ├── atuin/
│   ├── zed/
│   ├── alacritty/
│   ├── uv/
│   └── gh/
├── dot_ssh/
│   ├── config
│   └── allowed_signers
└── Repos/
    └── ghr.toml
```

## Platform

Primarily targeting **macOS (Apple Silicon)**. Templates use `.chezmoi.os` and
`.chezmoi.arch` to generate machine-specific values (e.g. Cargo `target`, CPU
`jobs`) at apply time.
