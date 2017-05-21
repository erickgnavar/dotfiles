# postgres.app setup
export PATH=/usr/local/bin:$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

# virtualenvwrapper
export WORKON_HOME=~/.virtualenvs
source ~/Library/Python/2.7/bin/virtualenvwrapper.sh
# TODO: change to relative path

# iterm2 integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
