# Display the available dotfiles maintenance tasks.
default:
    @just --list

# Refresh the stable Fish path used by native GUI applications.
refresh-fish-link:
    bash scripts/refresh-mise-fish-link

# Install globally configured mise tools and refresh dependent links.
upgrade:
    mise self-update -y
    mise upgrade --bump
    mise reshim
    bash scripts/refresh-mise-fish-link
    rustup update
    uv tool upgrade --all

# Verify the main development environment prerequisites.
doctor:
    #!/usr/bin/env bash
    set -euo pipefail

    printf 'Checking mise...\n'
    command -v mise >/dev/null

    printf 'Checking chezmoi...\n'
    command -v chezmoi >/dev/null

    printf 'Checking Fish managed by mise...\n'
    fish_path="$(mise which fish)"
    test -x "$fish_path"

    printf 'Checking stable Fish link...\n'
    test -L "$HOME/.local/bin/fish"
    test -x "$HOME/.local/bin/fish"

    printf 'Checking global Git ignore...\n'
    test -f "$HOME/.config/git/ignore"

    printf 'All checks passed.\n'
