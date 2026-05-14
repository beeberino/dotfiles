export TERM="xterm-256color"

alias ls="ls -Gp"
alias d_ds="find . -name .DS_Store -print0 | xargs -0 git rm --ignore-unmatch"
alias ruby-server="ruby -r webrick -e \"s = WEBrick::HTTPServer.new(:Port => 9090, :DocumentRoot => Dir.pwd); trap('INT') { s.shutdown }; s.start\""
alias lines="find . -name '*.*' | xargs wc -l"

alias wd='jump'

alias be='bundle exec'
alias bi='bundle install'
alias bu='bundle update'
alias ber="bundle exec rails"
alias brake='bundle exec rake'
alias bes="bundle exec rspec"
alias besr="bundle exec rspec --order rand"

alias zrc="vim ~/.dotfiles/.zshrc"
alias vrc="vim ~/.dotfiles/.vimrc"

alias chat="profanity -d"
alias scrape="wget -e robots=off -r -nc -np"

alias mktag="ctags -R --exclude=.git --exclude=log ."
alias rtag='ctags -R --exclude=.git --exclude=log . `bundle show --paths`'

alias work="ssh thomas@10.0.40.14 -t tmux a"

timed_command () { perl -e 'alarm shift; exec @ARGV' "$@"; }
fuck() { ps -e | grep $1 | ruby -e "ARGF.read.to_s.split(/\\n/).each { |l| puts l.split(' ').first }" | xargs -L 1 kill -9 }
187() { if [ "$#" -eq 1 ]; then rvm use 1.8.7-p374@$1; else rvm use 1.8.7-p374; fi }
210() { if [ "$#" -eq 1 ]; then rvm use 2.1.0@$1; else rvm use 2.1.0; fi }
212() { if [ "$#" -eq 1 ]; then rvm use 2.1.2@$1; else rvm use 2.1.2; fi }
193() { if [ "$#" -eq 1 ]; then rvm use 1.9.3@$1; else rvm use 1.9.3; fi }

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to disable command auto-correction.
# DISABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# use colors
source ~/.zsh/colors.sh

# makes color constants available
autoload -U colors
colors

# history settings
export HISTFILE=$HOME/.zsh_history
export SAVEHIST=10000 # amt of cmds in HISTFILE
export HISTFILESIZE=10000 # amt of cmds in HISTFILE
export HISTSIZE=10000     # amt of cmds in history list of current session
export HISTAPPEND=true    # all bash shells will share the same history file instead of overwritting

setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_no_store
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_verify
setopt inc_append_history
setopt no_hist_allow_clobber
# setopt no_hist_beep
setopt share_history

# command history autocomplete
# autoload -U up-line-or-beginning-search
# autoload -U down-line-or-beginning-search
# zle -N up-line-or-beginning-search
# zle -N down-line-or-beginning-search
# bindkey "^[[A" up-line-or-beginning-search # Up
# bindkey "^[[B" down-line-or-beginning-search # Down

#enable colored output from ls, etc
export CLICOLOR=1
export ZSH_THEME_GIT_PROMPT_NOCACHE=1

source $HOME/.zshrc.local
source ~/.dotfiles/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

eval "$(rbenv init -)"
eval "$(pyenv init -)"
eval "$(starship init zsh)"
export PATH="/usr/local/opt/qt@5.5/bin:$PATH"
source /Users/thomaswatts/.dotfiles/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform
