function virtualenv_info () {
    [ $VIRTUAL_ENV ];
}

function get_pwd() {
    echo "${PWD/$HOME/~}"
}

PROMPT='$fg[white]$(virtualenv_info)$fg[red]%n$fg[white] at $fg[yellow]%m $fg[white]in $fg[magenta]$(get_pwd) $fg[cyan]$(git_prompt_info)
λ$reset_color '
