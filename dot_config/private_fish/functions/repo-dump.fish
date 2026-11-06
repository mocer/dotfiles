function repo-dump --description "Dump textual files of current repository"
    set outfile /tmp/(basename $PWD)-(date +%Y%m%d-%H%M%S).txt

    echo "===== REPOSITORY =====" >$outfile
    echo $PWD >>$outfile
    echo >>$outfile

    echo "===== TREE =====" >>$outfile

    if command -q eza
        eza --tree --git-ignore --level=5 >>$outfile 2>/dev/null
    else
        ls -la */** >>$outfile 2>/dev/null
    end

    echo >>$outfile
    echo "===== FILES =====" >>$outfile

    for fl in (
        fd -t file -H \
            --exclude .git \
            --exclude .jj \
            --exclude node_modules \
            --exclude target \
            --exclude dist \
            --exclude build \
            --exclude .direnv \
            --exclude .mise \
            --exclude .cache \
            --exclude .next \
            --exclude coverage \
            .
    )

        if file --brief --mime-encoding "$fl" | string match -q binary
            continue
        end

        printf "\n\n===== FILE: %s =====\n" "$fl" >>$outfile

        if command -q bat
            bat --plain --color=never "$fl" >>$outfile
        else
            cat "$fl" >>$outfile
        end

        printf "\n===== END FILE: %s =====\n" "$fl" >>$outfile
    end
    echo >&2 "Dump done: $outfile"
    printf "%s\n" $outfile
end
