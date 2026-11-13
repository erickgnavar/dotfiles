# A small Pure-style prompt with asynchronous local Git/JJ checks; no fetches.
autoload -Uz add-zsh-hook
zmodload zsh/datetime
zmodload zsh/zpty

# Build literal prompt text, not through shell substitutions.
unsetopt promptsubst

_pure_cleanup() {
  if [[ -n ${_pure_fd-} ]]; then
    zle -F "$_pure_fd"
    # zpty deletes the worker and signals its entire process group.
    if ! zpty -d _pure_worker 2>/dev/null; then
      # Also allow reloading from the old process-substitution implementation.
      exec {_pure_fd}<&-
    fi
    unset _pure_fd _pure_output
  fi
}

# Drop an old worker's descriptor when sourcing this file again.
_pure_cleanup
_pure_git=''
_pure_kube=''
_pure_git_pwd=''
_pure_git_checked=0
_pure_running=0

_pure_kube_refresh() {
  _pure_kube=''
  _pure_git_checked=0
  [[ -n ${_pure_fd-} ]] && _pure_cleanup
}

_pure_render() {
  local nix_shell='' ssh_identity=''
  # Show the remote identity using native Zsh prompt expansions.
  if [[ -n ${SSH_CONNECTION-} || -n ${SSH_TTY-} ]]; then
    ssh_identity='%F{242}%n@%m%f '
  fi
  # nix-shell and nix develop set IN_NIX_SHELL (usually pure or impure).
  [[ -n ${IN_NIX_SHELL-} ]] && nix_shell=' %F{cyan}nix-shell%f'
  PROMPT=$'\n'"${ssh_identity}"'%F{blue}%~%f'
  PROMPT+="${_pure_git}${_pure_kube}${nix_shell}${_pure_duration}"
  PROMPT+=$'\n'"%F{${_pure_color}}❯%f "
  RPROMPT=''
}

_pure_git_ready() {
  local result
  if [[ $1 != ${_pure_fd-} ]]; then
    return
  fi
  # A closed writer can report hup while its final result is still buffered.
  if [[ -z ${2-} || ${2-} == hup ]] && zpty -rt _pure_worker result; then
    _pure_output=${_pure_output-}$result
    if [[ $_pure_output != *$'\n' ]]; then
      [[ -n ${2-} ]] && _pure_cleanup
      return 0
    fi
    result=${_pure_output%$'\n'}
    result=${result%$'\r'}
    if [[ $PWD == $_pure_git_pwd ]]; then
      _pure_git=${result%%$'\t'*}
      _pure_kube=${result#*$'\t'}
      _pure_git_checked=$EPOCHSECONDS
      _pure_render
      if ((_pure_running == 0)) && zle; then
        zle reset-prompt
      fi
    fi
  elif [[ -z ${2-} ]] && zpty -t _pure_worker; then
    # No complete result yet; wait for the next readable event.
    return
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

  _pure_worker() {
    # Keep Git/JJ and their children in the worker's isolated process group.
    unsetopt monitor
    trap - HUP
    local git_state line git_dir operation oid branch='' dirty='' details=''
    local kube='' kube_context kube_display kube_project
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
    if command -v kubectl >/dev/null 2>&1; then
      kube_context=$(command kubectl config current-context 2>/dev/null)
      kube_context=${kube_context//[[:cntrl:]]/ }
      if [[ -n $kube_context ]]; then
        kube_display=$kube_context
        if [[ $kube_context == gke_*_*_* ]]; then
          kube_project=${kube_context#gke_}
          kube_project=${kube_project%%_*}
          kube_display="$kube_project/${kube_context#*_*_*_}"
        fi
        if [[ ${kube_context:l} == *prod* ]]; then
          kube=" %F{red}k8s(${kube_display//\%/%%})%f"
        else
          kube=" %F{cyan}k8s(${kube_display//\%/%%})%f"
        fi
      fi
    fi
    print -r -- "$details"$'\t'"$kube"
  }
  if zpty -b _pure_worker _pure_worker; then
    _pure_fd=$REPLY
    zle -F "$_pure_fd" _pure_git_ready
  fi
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
