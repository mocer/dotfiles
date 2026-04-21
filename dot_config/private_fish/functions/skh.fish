function skh --description "Fuzzy-find a file and open it in helix (optional: pass a root directory)"
    set root (if test (count $argv) -gt 0; echo $argv[1]; else; echo .; end)
    set f (fd --type f . $root | sk --prompt "Pick a file> " \
        --preview 'bat --color=always --style=numbers {}')
    and hx $f
end
