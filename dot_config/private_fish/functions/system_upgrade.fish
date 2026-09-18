function system_upgrade --description "Run the dotfiles system upgrade workflow"
    if not command -q chezmoi
        echo "ERROR: chezmoi is not available in PATH." >&2
        return 1
    end

    if not command -q just
        echo "ERROR: just is not available in PATH." >&2
        return 1
    end

    set -l source_dir (chezmoi source-path 2>/dev/null)

    if test $status -ne 0 -o -z "$source_dir"
        echo "ERROR: unable to resolve the chezmoi source directory." >&2
        return 1
    end

    set -l justfile "$source_dir/justfile"

    if not test -f "$justfile"
        echo "ERROR: dotfiles justfile not found:" >&2
        echo "       $justfile" >&2
        return 1
    end

    echo "==> Running the dotfiles system upgrade workflow"

    command just \
        --justfile "$justfile" \
        --working-directory "$source_dir" \
        upgrade

    set -l upgrade_status $status

    if test $upgrade_status -ne 0
        echo >&2
        echo "ERROR: system upgrade failed." >&2
        return $upgrade_status
    end

    echo
    echo "System upgrade completed successfully."
end
