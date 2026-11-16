# Recipes run through Nushell on every OS: same syntax on macOS, Linux, Windows.
# Multi-line logic lives in scripts/*.nu, not here.
set shell := ["nu", "-c"]
set windows-shell := ["nu", "-c"]

# Display the available dotfiles maintenance tasks.
default:
    @just --list

# Refresh the stable ~/.local/bin links used by native applications and Cargo.
refresh-links:
    nu scripts/refresh-links.nu

# Regenerate the Nushell vendor autoload files (mise, starship, zoxide, atuin, carapace).
nushell-init:
    nu scripts/nushell-init.nu

# Verify the main development environment prerequisites.
doctor:
    nu scripts/doctor.nu

# Upgrade tools (Nushell is held), sync the bumped mise config back, refresh generated state.
upgrade:
    nu scripts/upgrade.nu

# Move Nushell to <version>; restores the previous version if any check fails.
upgrade-nu version:
    nu scripts/upgrade-nu.nu {{version}}
