source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi

source $(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[5~' history-substring-search-up
bindkey '^[[6~' history-substring-search-down

source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source <(fzf --zsh)
eval "$(zoxide init --cmd cd zsh)"

eval "$(starship init zsh)"

eval "$(~/Library/Python/3.9/bin/aactivator init)"
pyvenv() {
    local name=${1:-venv}
    local pybin=${2:-python3}
    $pybin -m venv $name
    echo "source venv/bin/activate" >> .activate.sh
    echo "deactivate" >> .deactivate.sh
}
