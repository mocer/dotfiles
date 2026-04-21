function repo --description "Fuzzy-pick a managed repository and cd into it"
    set selected (ghr list --path | sk --prompt "Pick a repo> " --query "$argv" \
        --preview 'eza --tree --level=2 --icons --color=always {} 2>/dev/null')
    and z $selected
end
