# dotfiles

Personal configuration files managed with [chezmoi](https://chezmoi.io), targeting multiple OS.
Profiles for multiple identities (personal and work) are handled transparently via [ghr](https://github.com/nicholasgasior/ghr).

## Quick Start

On a new machine:

```fish
chezmoi init --apply https://github.com/mocer/dotfiles
```

## Managed Tools

### Shell
| Tool | Description |
|------|-------------|
| [Fish](https://fishshell.com) | Primary shell — PATH, env vars, aliases, abbreviations |
| [Starship](https://starship.rs) | Minimal, fast cross-shell prompt |
| [Atuin](https://atuin.sh) | SQLite-backed shell history sync and search |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` replacement |
| [Direnv](https://direnv.net) | Per-directory environment variable management |

### Version Control
| Tool | Description |
|------|-------------|
| [Git](https://git-scm.com) | Global config, SSH signing, allowed signers |
| [gh](https://cli.github.com) | GitHub CLI configuration |
| [ghr](https://github.com/nicholasgasior/ghr) | Multi-profile and multi-host Git identity manager |
| [jj](https://martinvonz.github.io/jj) | Jujutsu — next-generation Git-compatible VCS |
| SSH | `~/.ssh/config`, public keys, `allowed_signers` |

### Development Environment
| Tool | Description |
|------|-------------|
| [mise](https://mise.jdx.dev) | Polyglot runtime and tool version manager |
| [Cargo / Rust](https://doc.rust-lang.org/cargo) | Sparse registry, sccache wrapper, target triple |
| [sccache](https://github.com/mozilla/sccache) | Compiler cache — path and size configuration |
| [rustup](https://rustup.rs) | Rust toolchain manager settings |
| [uv](https://github.com/astral-sh/uv) | Fast Python package and project manager |
| [Deno](https://deno.com) | Secure TypeScript/JavaScript runtime |

### Editors
| Tool | Description |
|------|-------------|
| [Helix](https://helix-editor.com) | Modal editor — keybindings, theme, language servers |
| [Zed](https://zed.dev) | High-performance collaborative editor |

### Terminal
| Tool | Description |
|------|-------------|
| [Alacritty](https://alacritty.org) | GPU-accelerated terminal emulator |
| [bat](https://github.com/sharkdp/bat) | `cat` replacement with syntax highlighting and man pager |
| [eza](https://eza.rocks) | Modern `ls` replacement |
| [bottom](https://github.com/ClementTsang/bottom) | Cross-platform graphical process monitor |

### Productivity & Search
| Tool | Description |
|------|-------------|
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast line-oriented search |
| [fd](https://github.com/sharkdp/fd) | Fast and user-friendly `find` alternative |
| [skim](https://github.com/lotabout/skim) | Fuzzy finder — used by `repo` function and zoxide |
| [just](https://just.systems) | Command runner and task organizer |

### Secrets & Security
| Tool | Description |
|------|-------------|
| [rbw](https://github.com/doy/rbw) | Bitwarden/Vaultwarden CLI client — server and email config only |
| [rage](https://github.com/str4d/rage) | Modern file encryption (age format) |

> **Note:** Private SSH keys and OAuth tokens are never committed to this repository.
> Sensitive files are either encrypted via `chezmoi add --encrypt` or excluded entirely.

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

Primarily targeting **macOS (Apple Silicon)**. Templates use `.chezmoi.os` and `.chezmoi.arch`
to generate machine-specific values (e.g. Cargo `target`, CPU `jobs`) at apply time.
