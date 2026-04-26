# Only init these in interactive shell sessions (avoids issues in e.g. agentic usecases)
if [[ $- == *i* ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

    if type brew &>/dev/null; then
        FPATH="$HOMEBREW_PREFIX/share/zsh-completions:$FPATH"
        autoload -Uz compinit
        compinit
    fi

    source "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    bindkey '^[[5~' history-substring-search-up    # fn+Up
    bindkey '^[[6~' history-substring-search-down  # fn+Down

    source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

    source <(fzf --zsh)

    eval "$(zoxide init --cmd cd zsh)"
fi

alias ls='lsd'
alias lsa='ls -a'
alias lsl='ls -l'
alias lsal='ls -al'
alias lst='ls --tree'
alias lsat='ls -a --tree'

eval "$(starship init zsh)"

eval "$(~/Library/Python/3.9/bin/aactivator init)"
pyvenv() {
    local name=${1:-venv}
    local pybin=${2:-python3}
    $pybin -m venv $name
    echo "source venv/bin/activate" >> .activate.sh
    echo "deactivate" >> .deactivate.sh
}
