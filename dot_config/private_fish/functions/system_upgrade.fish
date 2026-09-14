function system_upgrade --description "Upgrade managed tools and reconcile local machine state"
    if not command -q chezmoi
        echo "ERROR: chezmoi is not available in PATH." >&2
        return 1
    end

    if not command -q mise
        echo "ERROR: mise is not available in PATH." >&2
        return 1
    end

    set -l source_dir (chezmoi source-path 2>/dev/null)

    if test $status -ne 0 -o -z "$source_dir"
        echo "ERROR: unable to resolve the chezmoi source directory." >&2
        return 1
    end

    set -l refresh_script "$source_dir/scripts/refresh-mise-fish-link"

    if not test -f "$refresh_script"
        echo "ERROR: Fish link refresh script not found:" >&2
        echo "       $refresh_script" >&2
        return 1
    end

    echo "==> Upgrading chezmoi"
    chezmoi upgrade
    or return 1

    echo "==> Updating mise"
    mise self-update -y
    or return 1

    echo "==> Upgrading mise-managed tools"
    mise upgrade --bump
    or return 1

    echo "==> Updating mise shims"
    mise reshim
    or return 1

    echo "==> Refreshing the stable Fish link"
    bash "$refresh_script"
    or return 1

    echo "==> Updating Rust toolchains"
    rustup update
    or return 1

    echo "==> Updating uv-managed tools"
    uv tool upgrade --all
    or return 1

    echo
    echo "System upgrade completed successfully."
end
