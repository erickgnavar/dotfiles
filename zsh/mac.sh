# postgres.app setup
export PATH=/usr/local/bin:$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

# Setup gettext binaries
export PATH="/usr/local/opt/gettext/bin:$PATH"

# virtualenvwrapper
export WORKON_HOME=~/.virtualenvs
export PATH=$PATH:$HOME/Library/Python/2.7/bin
# shellcheck source=/dev/null
. "$HOME/Library/Python/2.7/bin/virtualenvwrapper.sh"

# Setup asdf
export ASDF_DIR="/usr/local/opt/asdf"
# shellcheck source=/dev/null
. "$ASDF_DIR/asdf.sh"
