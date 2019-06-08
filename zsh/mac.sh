# postgres.app setup
export PATH=/usr/local/bin:$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

# virtualenvwrapper
export WORKON_HOME=~/.virtualenvs
export PATH=$PATH:$HOME/Library/Python/2.7/bin
# shellcheck source=/dev/null
. "$HOME/Library/Python/2.7/bin/virtualenvwrapper.sh"
