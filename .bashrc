# "[in trial]" means something is still an experiment in my workflow

# Prompt
# * show a simple prompt
# * enable vim mode [in trial]
# * clear the terminal screen with <Control-l>
# * insert the last argument of last command with <Control-k> [in trial]
PS1='\w\n'"\[\e[34m\]$\[\e[m\] "
set -o vi
bind -m vi-insert '\C-l:clear-screen'
bind -m vi-command '\C-k:insert-last-argument'

# Recursive Alias Expansion: chain aliases when using sudo & doas.
# "If the last character of the alias value is a blank, then the next command
# word following the alias is also checked for alias expansion" -- the bash
# manual, section 6.6
alias doas='doas '
alias sudo='sudo '

# Command History: 
# * append only: don't overwite the history file, this should be the default in
#   bash.
# * ignore duplicates: should be the default as well.
# * stay in sync with other bash processes
# * use mcfly for smarter history matching. [in trial].
#   mcfly currently requires setting `sysct dev.tty.legacy_tiocsti=1` on newer
#   kernels, this is tracked on issues: #333, #371
shopt -s histappend
export HISTCONTROL='ignoredups'
export PROMPT_COMMAND=$PROMPT_COMMAND';history -a; history -c; history -r;'
#export MCFLY_FUZZY=2
source /usr/share/doc/mcfly/mcfly.bash
shopt -s histverify # don't blindly execute commands from history

# Autocomplete: provide completion with carapace-bin
eval "$(carapace _carapace bash)"

# File Operations
# * make mv and cp interactive
# * aesthetics
# * trash support
alias mv='mv -i'
alias cp='cp -i'
alias ls='exa -al --color=always --group-directories-first'
alias rm='gio trash'

# Text Processing
alias cat='bat'
alias grep='grep --color=auto'

# Media Scarping
# * ydl and gdl: shortcut yt-dlp and gallery-dl to ydl and gdl
# * $cookies: set the $cookies variable and have ydl and gdl automatically use
#   it
# * watch the clipboard for urls to pass to ydl and gdl
# * queue: watch the clipboard for urls to add to a queue
# * dequeue: download from a queue with ydl or gdl
ydl(){
  local flags=()
  [[ -n "$cookies" ]] && flags+=("--cookies" "$cookies")
  command yt-dlp ${flags[@]} $@
}
gdl(){
  local flags=()
  [[ -n "$cookies" ]] && flags+=("--cookies" "$cookies")
  command gallery-dl ${flags[@]} $@
}

alias ydlwatch='while clipnotify; do ydl $(wl-paste)& done;'
alias gdlwatch='while clipnotify; do gallery-dl $(wl-paste)& done'

alias queue='while clipnotify; do wl-paste >> queue& done;'
alias gdlq='gdl --input-file-delete queue'
alias ydlq='ydl --batch-file queue'

# Scrcpy Aliases
alias s='scrcpy'
alias sna='scrcpy --no-audio'
alias srec='scrcpy --record $HOME/scrcpy-recording-$(date -u +%Y-%m-%dT%H:%M:%S%Z).mp4'

# Dotfiles Management
alias gitdotfiles="git --git-dir='$HOME/.dotfiles/' --work-tree='$HOME'"
alias dfadd='gitdotfiles add'
alias dfcmt='gitdotfiles commit'
alias dfsts='gitdotfiles status'
alias dfpsh='gitdotfiles push'

# Common Pacman Operations
alias pacs='pacman -S'     # install a package from the repos
alias pacss='pacman -Ss'   # search the repos for a package
alias pacsyu='pacman -Syu' # sync the repos & update all packages
alias pacsi='pacman -Si'   # display package infos from the repos
alias pacqs='pacman -Qs'   # search installed packages
alias pacqi='pacman -Qi'   # display infos regarding an installed package
alias pacql='pacman -Ql'   # list files comprising an installed package
alias pacfl='pacman -Fl'   # list files comprising a repo package
alias pacf='pacman -F'     # find to which package a file belong
#alias pacclean='doas pacman -Rns (pacman -Qtdq)' # remove uneeded packages

# AUR
# TODO: better integrate aurutils with fzf, the current implementation is
# unredable after a few weeks of writing
alias aursrch="aur search"
alias aursync="aur sync"
aurs(){
  local format="Description: %d\nVersion: %v"
  local results=$(aur query -t search "$1" | aur format --format '%n\t%d\n')
  local choice=$(cut -f1 <<< $(fzf --reverse <<< "$results" --preview='aur query -t info $(cut -f1 <<< {}) | aur format -f "'"$format"'"'))
  [[ ! -z "$choice" ]] && aur sync "$choice"
}

# Editor
export EDITOR='nvim'
alias dev='NVIM_APPNAME=nvim-dev neovide --no-fork'
alias mnd='NVIM_APPNAME=nvim-mnd neovide --no-fork'

# Man
# use bat as a man pager
# an integration issues between groff and bat require some working aroud
# (relevant github issues: bat#2668 and bat#2593)
export MANROFFOPT='-c'
export MANPAGER='sh -c "col -bx | bat -l man -p"'

# Filesystem Navigation
# * autocd: change directory without cd
# * cl: cd to the last argument of the last command [trial]
# * mkcd: to make a directory and cd to it [trial]
# * cd: override cd to jump to the frequently vistied directory that matches
#   the first argument
# * cdi: iteractively cd to frequently vistied directories [trial]
# * lf: override lf to jump to the frequently visited directory that matches
#   the first argument, also check if lf has left a cd-file and cd to it's content
# * C-t to pick files to insert into the current line
# * TODO: maybe C-f to cd to a directory using lf without leaving the prompt
# * TODO: maybe C-z to cd to a directory using zoxide without leaving the prompt
shopt -s autocd
alias cl="builtin cd -- \$(fc -ln -1 | awk '{print $NF}'"
mkcd(){ 
  command mkdir -- "$1" && _cd_and_add_to_zoxide "$1"
}
cdi() {
  local res=$(command zoxide query --interactive "$@") && builtin cd -- "$res";
}
cd() {
  # if no arguments are given, cd to $HOME
  if [[ "$#" -eq 0 ]]; then 
    builtin cd -- "$HOME"
  # handle `--` for compatibility with the builtin cd, (to accomodate autocd)
  elif [[ "$1" == "--" ]]; then _cd_and_add_to_zoxide $2
  # if the argument is a directory, add it to zoxide and cd to it
  elif [[ -d "$1" ]]; then _cd_and_add_to_zoxide $2
  # if zoxide query returns a valid directory, cd to it
  elif res=$(command zoxide query "$@"); then
    builtin cd -- "$res"
  fi
}

lf () {
  # remove the `lf-cd` file if it exists 
  local path="$XDG_RUNTIME_DIR"/lf-cd
  [[ -f "$path" ]] && command rm -- $path
  # If no arguments are given, lf to $PWD
  if [[ "$#" -eq 0 ]]; then 
    command lf "$PWD"
  # If the argument is a directory, add it to zoxide and lf to it
  elif [[ -d "$1" ]] then
    command zoxide add "$1" && command lf "$1";
  # If zoxide query returns a valid directory, lf to it
  elif res=$(command zoxide query "$@"); then
    command lf "$res";
  fi;
  # cd to the content of the `lf-cd` file
  [[ -f "$path" ]] && cd -- "$(< "$path")"
}
_cd_and_add_to_zoxide(){
    command zoxide add "$1" && builtin cd -- "$1"
}

bind -m vi-insert -x '"\C-t":select_files'
select_files() {
  local selected_files="$(select_files_with_lf)";
  insert_into_readline "$selected_files" "$READLINE_POINT";
}
select_files_with_lf() {
  command lf -print-selection |
  while read -r item; do printf ' %s' "$(_escape_path "$item")";  done
}
#select_files_with_fzf() {
#  local find_cmd="fd . ${PWD} --type directory --type file --type symlink 2> /dev/null"
#  local fzf_flags="--layout=reverse --info=inline --height 8 --no-unicode --scheme=path --multi"
#  eval "$find_cmd" |
#    FZF_DEFAULT_OPTS="$fzf_flags" fzf
#}
insert_into_readline() {
  local selected=$1;
  READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$selected${READLINE_LINE:$READLINE_POINT}"
  READLINE_POINT=$(( READLINE_POINT + ${#selected} ))
}
_escape_path() {
  printf '%q' "$1";
}
