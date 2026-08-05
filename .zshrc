if [[ $- == *i* ]]; then
    # Only init these in interactive shell sessions (avoids issues in e.g. agentic usecases)

    alias bdl='bd list'
    alias bdla='bd list --all'
    alias bub='brew update && brew upgrade -y && brew cleanup'
    alias ls='lsd'
    alias lsa='ls -a'
    alias lsl='ls -l'
    alias lsal='ls -al'
    alias lst='ls --tree'
    alias lsat='ls -a --tree'
    alias nv='nvim'

    if [[ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi

    if type brew &>/dev/null && [[ -d "$HOMEBREW_PREFIX/share/zsh-completions" ]]; then
        FPATH="$HOMEBREW_PREFIX/share/zsh-completions:$FPATH"
        autoload -Uz compinit
        compinit
    fi

    if [[ -f "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
        bindkey '^[[5~' history-substring-search-up    # fn+Up
        bindkey '^[[6~' history-substring-search-down  # fn+Down
    fi

    if [[ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
        source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    fi

    source <(fzf --zsh)
    eval "$(zoxide init --cmd cd zsh)"
fi

eval "$(starship init zsh)"

# aactivator setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -f ~/Library/Python/3.9/bin/aactivator ]]; then
        eval "$(~/Library/Python/3.9/bin/aactivator init)"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v aactivator &>/dev/null; then
        eval "$(aactivator init)"
    elif [[ -f ~/.local/bin/aactivator ]]; then
        eval "$(~/.local/bin/aactivator init)"
    fi
fi

pyvenv() {
    local name=${1:-venv}
    local pybin=${2:-python3}
    $pybin -m venv $name
    echo "source $name/bin/activate" > .activate.sh
    echo "deactivate" > .deactivate.sh
}
