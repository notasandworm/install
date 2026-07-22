# ==============================================================================
# 1. ENVIRONMENT & PROMPT INITIALIZATION
# ==============================================================================
# Set keybindings to Emacs mode
# bindkey -e

# Initialize prompt system
# autoload -Uz promptinit && promptinit
# prompt adam1

# ==============================================================================
# 2. HISTORY SETTINGS
# ==============================================================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt APPEND_HISTORY          # Append history to file rather than overwrite
setopt SHARE_HISTORY           # Share history across shell instances immediately
setopt EXTENDED_HISTORY        # Save timestamp and execution duration
setopt HIST_IGNORE_ALL_DUPS    # Purge older duplicate entries when adding new ones
setopt HIST_IGNORE_SPACE       # Do not record commands preceded by a space

# ==============================================================================
# 3. AUTOCOMPLETION SYSTEM
# ==============================================================================
autoload -Uz compinit && compinit

# Enable colorized ls output mapping if dircolors is present
if (( $+commands[dircolors] )); then
    eval "$(dircolors -b)"
    zstyle ':completion:default' list-colors ${(s.:.)LS_COLORS}
fi

# Completion matching & visual behavior
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose true
zstyle ':completion:*' use-compctl false

# Matcher list: Case-insensitive -> substring -> partial-word matching
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Interactive selection prompts
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or typed character to insert%s'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'

# Enhanced process completion for 'kill' command
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# ==============================================================================
# 4. KEYBINDINGS & HISTORY SEARCH
# ==============================================================================
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Prefix history search using arrow keys
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# ==============================================================================
# 5. SHELL OPTIONS
# ==============================================================================
setopt AUTO_CD                 # Change directory without typing 'cd'
setopt NO_BEEP                 # Suppress terminal audio alerts

# ==============================================================================
# *. MATT's SETTINGS
# ==============================================================================
. "$HOME/.local/bin/env"
export PATH="$PATH:$HOME/.local/bin"

alias ls="eza --icons=always --colour=always"
alias la="eza -alog --git --icons=always --colour=always"
alias ll="eza -log --git --icons=always --colour=always"
alias bat="batcat"

eval "$(zoxide init --cmd cd zsh)"
eval "$(starship init zsh)"

# ==============================================================================
# *. MATT's SHELL FUNCTIONS
# ==============================================================================
update-nvim() {
    # Exit early if any command in the pipeline fails
    set -e

    local TARGET_DIR="$HOME/.local/share/nvim-root"
    local BIN_DIR="$HOME/.local/bin"
    local TMP_WORKSPACE
    
    # Create a secure, isolated temporary workspace
    TMP_WORKSPACE=$(mktemp -d /tmp/nvim-update-XXXXXX)
    
    # Ensure temporary workspace files are destroyed on errors or exit
    trap 'rm -rf "$TMP_WORKSPACE"' EXIT

    echo "Fetching the latest Neovim AppImage..."
    cd "$TMP_WORKSPACE"
    
    # -L follows redirects; -sS hides progress bar but shows errors
    if ! curl -LOsS https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage; then
        echo "Error: Failed to download Neovim AppImage." >&2
        return 1
    fi
    chmod +x nvim-linux-x86_64.appimage

    echo "Extracting AppImage contents..."
    # Extract to a deterministic folder inside our temp workspace
    ./nvim-linux-x86_64.appimage --appimage-extract > /dev/null

    if [ ! -d "squashfs-root" ]; then
        echo "Error: Extraction failed." >&2
        return 1
    fi

    echo "Relocating binaries safely..."
    mkdir -p "$BIN_DIR"
    
    # Remove old extraction target completely to avoid nested directories
    rm -rf "$TARGET_DIR"
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    # Move the fresh extraction out of the temporary workspace
    mv squashfs-root "$TARGET_DIR"

    # Atomic symlink replacement (forces overwrite safely)
    ln -sf "$TARGET_DIR/AppRun" "$BIN_DIR/nvim"

    echo "Neovim updated successfully! Current version:"
    "$BIN_DIR/nvim" --version | head -n 1
}
. '/home/matt/.cargo/env'


# Added by Antigravity CLI installer
export PATH="/home/matt/.local/bin:$PATH"
