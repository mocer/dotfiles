### 1. PATH CONFIGURATION
# In Fish, the last 'fish_add_path' command has the highest priority.
# We stack them from lowest to highest importance.

# System & legacy paths (Lowest priority)
fish_add_path /usr/local/bin /opt/local/bin $HOME/.openshift/bin

# MISE, local and Cargo binaries(For tools installed via rustup)
fish_add_path $HOME/.local/bin $HOME/.cargo/bin

# Mise shims (HIGHEST PRIORITY)
# This ensures that Mise tools (as taplo, deno, xh, ...) are found before 
fish_add_path $HOME/.local/share/mise/shims

### 2. ENVIRONMENT VARIABLES
# Rustup and Cargo directory configuration
set -gx RUSTUP_HOME $HOME/.rustup
set -gx CARGO_HOME $HOME/.cargo
set -gx CARGO_TARGET_DIR $CARGO_HOME/target

# Sccache: caches rustc artifacts across projects and invocations.
# rustc-wrapper is declared in ~/.cargo/config.toml; cargo resolves it at build time.
# In non-interactive shells (Zed LSP, launchd, daemons) mise shims are not on PATH,
# so cargo cannot find sccache. Symlink bridges the gap:
#   ln -sf ~/.local/share/mise/shims/sccache ~/.cargo/bin/sccache
set -gx SCCACHE_DIR $HOME/.cache/sccache
set -gx SCCACHE_CACHE_SIZE 50G # Sets the max cache size to 50 Gigabytes

# GHR repository and configuration directory 
set -gx GHR_ROOT "$HOME/Repos"

# to use ZOXIDE with skim than fzf
set -gx _ZO_FZF_OPTS ""
set -gx _ZOXIDE_FZF_CMD "sk --height 40% --layout=reverse --border rounded"

# bat as man pager
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx MANRPAGER "sh -c 'col -bx | bat -l man -p'"

# Localization and Language settings
set -x LANG it_IT.UTF-8
set -x LANGUAGE it_IT.UTF-8
set -x LC_ALL it_IT.UTF-8

### 3. INTERACTIVE INITIALIZATIONS
# These commands run only in interactive sessions

if status is-interactive
    # Initialize Mise (Quiet mode)
    mise activate -q fish | source

    # Other
    starship init fish | source
    atuin init fish | source
    zoxide init fish | source
    direnv hook fish | source

    if command -v ghr >/dev/null
        ghr shell fish | source && ghr shell fish --completion | source
    end

    # Shell greeting message
    set fish_greeting "Hi Mocer, may the force be with you!"
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

#ALIAS
alias ls "eza --icons --group-directories-first"
alias ll "eza --icons --group-directories-first -l --git"
alias la "eza --icons --group-directories-first -la --git"
alias lt "eza --icons --tree --level=2"
alias llt "eza --icons --tree --level=2 -l --git"

alias cat "bat --paging=never"

#ABBR - preserving shell history

abbr cb "cargo build"
abbr cbr "cargo build --release"
abbr ct "cargo nextest run"
abbr cw "cargo watch -x 'nextest run'"
abbr cc "cargo check"
abbr ccl "cargo clippy"
abbr cf "cargo fmt"

abbr cz chezmoi
abbr cza "chezmoi apply"
abbr czd "chezmoi diff"
abbr czr "chezmoi re-add"
abbr czs "chezmoi status"
abbr czcd "chezmoi cd"
abbr czad "chezmoi add"

abbr jl "jj log"
abbr jd "jj describe -m"
abbr jn "jj new"
abbr js "jj squash"
abbr jgp "jj git push"

abbr skfc "skf $HOME/.config"
