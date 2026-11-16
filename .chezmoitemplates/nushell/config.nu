# Nushell interactive configuration.
# Managed by chezmoi: edit .chezmoitemplates/nushell/config.nu in the dotfiles repository.
#
# Load order: env.nu → config.nu → vendor autoload → autoload/ (this directory).
# - vendor autoload ($nu.data-dir/vendor/autoload) holds the generated tool
#   integrations: mise, starship, zoxide, atuin, carapace (scripts/nushell-init.nu).
# - autoload/*.nu next to this file holds personal commands. They load after
#   this file, so nothing here may call them.

$env.config.show_banner = false
$env.config.buffer_editor = "hx"

# Terminal/tab title = current directory + running command.
# Replaces fish_title and fish_tab_title.
$env.config.shell_integration.osc2 = true
# Report the working directory, so new tabs/splits open in the same place.
$env.config.shell_integration.osc7 = true

# ── Aliases ──────────────────────────────────────────────────────────
# Nushell has no abbreviations: aliases replace them one-to-one.
#
# `ls` intentionally stays the structured built-in (tables, `where`, `sort-by`).
# eza is available under its own short names.
alias l   = eza --icons --group-directories-first
alias ll  = eza --icons --group-directories-first -l --git
alias la  = eza --icons --group-directories-first -la --git
alias lt  = eza --icons --tree --level=2
alias llt = eza --icons --tree --level=2 -l --git

alias cat = bat --paging=never

# Cargo
alias cb  = cargo build
alias cbr = cargo build --release
alias ct  = cargo nextest run
alias cw  = cargo watch -x "nextest run"
alias cc  = cargo check
alias ccl = cargo clippy
alias cf  = cargo fmt

# chezmoi
alias cza  = chezmoi apply
alias czd  = chezmoi diff
alias czr  = chezmoi re-add
alias czs  = chezmoi status
alias czcd = chezmoi cd
alias czad = chezmoi add

# Jujutsu
alias jl  = jj log
alias jd  = jj describe -m
alias jn  = jj new
alias js  = jj squash
alias jgp = jj git push

if $nu.is-interactive { print "Hi Mocer, may the force be with you!" }
