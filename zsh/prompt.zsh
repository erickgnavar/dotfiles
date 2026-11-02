# A small Pure-style prompt with asynchronous local Git/JJ checks; no fetches.
autoload -Uz add-zsh-hook
zmodload zsh/datetime

# Build literal prompt text, not through shell substitutions.
unsetopt promptsubst

_pure_cleanup() {
  if [[ -n ${_pure_fd-} ]]; then
    zle -F "$_pure_fd"
    exec {_pure_fd}<&-
    unset _pure_fd
  fi
}

# Drop an old worker's descriptor when sourcing this file again.
_pure_cleanup
_pure_git=''
_pure_git_pwd=''
_pure_git_checked=0
_pure_running=0

_pure_render() {
  local nix_shell='' ssh_identity=''
  # Show the remote identity using native Zsh prompt expansions.
  if [[ -n ${SSH_CONNECTION-} || -n ${SSH_TTY-} ]]; then
    ssh_identity='%F{242}%n@%m%f '
  fi
  # nix-shell and nix develop set IN_NIX_SHELL (usually pure or impure).
  [[ -n ${IN_NIX_SHELL-} ]] && nix_shell=' %F{cyan}nix-shell%f'
  PROMPT=$'\n'"${ssh_identity}"'%F{blue}%~%f'"${_pure_git}${nix_shell}${_pure_duration}"$'\n'"%F{${_pure_color}}❯%f "
  RPROMPT=''
}

_pure_git_ready() {
  local result
  if [[ $1 != ${_pure_fd-} ]]; then
    return
  fi
  # A closed writer can report hup while its final result is still buffered.
  if [[ -z ${2-} || ${2-} == hup ]] && IFS= read -r -u "$1" result; then
    if [[ $PWD == $_pure_git_pwd ]]; then
      _pure_git=$result
      _pure_git_checked=$EPOCHSECONDS
      _pure_render
      if ((_pure_running == 0)) && zle; then
        zle reset-prompt
      fi
    fi
  fi
  _pure_cleanup
}

_pure_git_start() {
  # Keep an existing check for this directory, but discard stale results.
  if [[ -n ${_pure_fd-} ]]; then
    [[ $PWD == $_pure_git_pwd ]] && return
    _pure_cleanup
  fi
  # Cache completed checks for five seconds, including outside repositories.
  if [[ $PWD == $_pure_git_pwd ]] &&
    ((EPOCHSECONDS - _pure_git_checked < 5)); then
    return
  fi
  if [[ $PWD != $_pure_git_pwd ]]; then
    _pure_git=''
  fi
  _pure_git_pwd=$PWD

  exec {_pure_fd}< <(
    local git_state line git_dir operation oid branch='' dirty='' details=''
    local ahead=0 behind=0
    local repo_dir=$PWD jj_state jj_change jj_dirty jj_conflict jj_bookmarks
    # Use the nearest repository; JJ wins when .jj and .git are colocated.
    while [[ $repo_dir != / && ! -e $repo_dir/.jj && ! -e $repo_dir/.git ]]; do
      repo_dir=${repo_dir:h}
    done
    if [[ -d $repo_dir/.jj ]] && command -v jj >/dev/null 2>&1; then
      # Never snapshot or update the working copy just to render the prompt.
      if jj_state=$(command jj --ignore-working-copy --color=never --no-pager log -G -r @ \
        -T 'change_id.short(8) ++ " " ++ if(empty, "0", "1") ++ " " ++
          if(conflict, "1", "0") ++ " " ++ local_bookmarks.map(|b| b.name()).join(", ")' \
        2>/dev/null); then
        # Bookmark names must not introduce prompt escapes or extra lines.
        IFS=' ' read -r jj_change jj_dirty jj_conflict jj_bookmarks \
          <<<"${jj_state//[[:cntrl:]]/ }"
        details=' %F{242}'
        [[ -n $jj_bookmarks ]] && details+="${jj_bookmarks//\%/%%} "
        details+="jj(${jj_change})"
        [[ $jj_dirty == 1 ]] && details+='%F{218}*'
        details+='%f'
        [[ $jj_conflict == 1 ]] && details+=' %F{yellow}conflict%f'
      fi
    # Read branch, dirtiness and local upstream counts from one status snapshot.
    elif git_state=$(GIT_OPTIONAL_LOCKS=0 command git status \
      --porcelain=v2 --branch --ahead-behind 2>/dev/null); then
      while IFS= read -r line; do
        case $line in
        '# branch.oid '*) oid=${line#\# branch.oid } ;;
        '# branch.head '*) branch=${line#\# branch.head } ;;
        '# branch.ab '*) read -r ahead behind <<<"${line#\# branch.ab }" ;;
        # Headers precede file records; one changed file is enough.
        [12u?]' '*)
          dirty='%F{218}*%F{242}'
          break
          ;;
        esac
      done <<<"$git_state"
      if [[ $branch == '(detached)' ]]; then
        branch=$(command git rev-parse --short "$oid" 2>/dev/null) || branch=$oid
      fi
      # Escape prompt sequences in branch names (for example, a literal %).
      details=" %F{242}git(${branch//\%/%%})${dirty}"
      ((ahead > 0)) && details+=" ↑${ahead#+}"
      ((behind < 0)) && details+=" ↓${behind#-}"
      details+='%f'
      # Resolve per-worktree metadata; rebase can also leave CHERRY_PICK_HEAD.
      if git_dir=$(command git rev-parse --absolute-git-dir 2>/dev/null); then
        operation=''
        if [[ -d $git_dir/rebase-merge || -d $git_dir/rebase-apply ]]; then
          operation=rebase
        elif [[ -f $git_dir/MERGE_HEAD ]]; then
          operation=merge
        elif [[ -f $git_dir/CHERRY_PICK_HEAD ]]; then
          operation=cherry-pick
        fi
        [[ -n $operation ]] && details+=" %F{yellow}${operation}%f"
      fi
    fi
    print -r -- "$details"
  )
  zle -F "$_pure_fd" _pure_git_ready
}

_pure_preexec() {
  _pure_running=1
  _pure_started=$EPOCHSECONDS
}

_pure_precmd() {
  local exit_code=$? elapsed days hours minutes duration=''
  _pure_running=0
  _pure_color=magenta
  _pure_duration=''

  if ((exit_code != 0)); then
    _pure_color=red
  fi
  if [[ -n ${_pure_started-} ]]; then
    elapsed=$((EPOCHSECONDS - _pure_started))
    if ((elapsed >= 5)); then
      days=$((elapsed / 86400))
      hours=$((elapsed / 3600 % 24))
      minutes=$((elapsed / 60 % 60))
      ((days > 0)) && duration+="${days}d "
      ((hours > 0)) && duration+="${hours}h "
      ((minutes > 0)) && duration+="${minutes}m "
      duration+="$((elapsed % 60))s"
      _pure_duration=" %F{yellow}${duration}%f"
    fi
  fi
  unset _pure_started

  _pure_git_start
  _pure_render
}

# add-zsh-hook avoids duplicate registrations when reloading .zshrc.
add-zsh-hook preexec _pure_preexec
add-zsh-hook precmd _pure_precmd
add-zsh-hook zshexit _pure_cleanup
