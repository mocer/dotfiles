# Display the available dotfiles maintenance tasks.
default:
    @just --list

# Refresh the stable Fish path used by native GUI applications.
refresh-fish-link:
    bash scripts/refresh-mise-fish-link

# Refresh the stable Deno path used by native GUI applications.
refresh-deno-link:
    bash scripts/refresh-mise-deno-link

# Refresh all stable paths used by native GUI applications.
refresh-links: refresh-fish-link refresh-deno-link
    
# Install globally configured mise tools and refresh dependent links.
upgrade:
    mise self-update -y
    mise upgrade --bump
    mise reshim
    just refresh-links
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

    printf 'Checking rustup...\n'
    command -v rustup >/dev/null

    printf 'Checking uv...\n'
    command -v uv >/dev/null

    printf 'Checking Fish managed by mise...\n'
    fish_path="$(mise which fish)"
    test -x "$fish_path"

    printf 'Checking stable Fish link...\n'
    fish_link="$HOME/.local/bin/fish"
    test -L "$fish_link"
    test -x "$fish_link"
    fish_target="$(readlink "$fish_link")"
    test "$fish_target" = "$fish_path"

    printf 'Checking Deno managed by mise...\n'
    deno_path="$(mise which deno)"
    test -x "$deno_path"

    printf 'Checking stable Deno link...\n'
    deno_link="$HOME/.local/bin/deno"
    test -L "$deno_link"
    test -x "$deno_link"
    deno_target="$(readlink "$deno_link")"
    test "$deno_target" = "$deno_path"

    printf 'Checking global Git ignore...\n'
    test -f "$HOME/.config/git/ignore"

    printf 'All checks passed.\n'
