function fish_title --description "Define a stable terminal title"
    # Avoid exposing the mise shim initialization command in terminal titles.
    # The title contains only the current directory and the active command.
    set -l current_directory (prompt_pwd)

    if test (count $argv) -gt 0; and test -n "$argv[1]"
        printf '%s: %s' "$current_directory" "$argv[1]"
    else
        printf '%s: fish' "$current_directory"
    end
end
