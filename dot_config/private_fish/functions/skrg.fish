function skrg --description "Search file contents with ripgrep and open it in helix"
    if test (count $argv) -eq 0
        echo "Usage: skrg <pattern>" >&2
        return 1
    end
    set result (rg --line-number --no-heading $argv[1] | \
        sk --prompt "Pick a match> " --delimiter ':' \
            --preview 'bat --color=always --style=numbers --highlight-line {2} {1}')
    or return
    set file (echo $result | cut -d: -f1)
    set line (echo $result | cut -d: -f2)
    and hx $file:$line
end
