# postgres.app setup
export PATH=/usr/local/bin:$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin

# Avoid auto update homwbrew packages
export HOMEBREW_NO_AUTO_UPDATE=1

# Setup gettext binaries
export PATH="/usr/local/opt/gettext/bin:$PATH"

# autojump setup
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# virtualenvwrapper
export WORKON_HOME=~/.virtualenvs
export PATH=$PATH:$HOME/Library/Python/2.7/bin
# shellcheck source=/dev/null
[ -f "$HOME/Library/Python/2.7/bin/virtualenvwrapper.sh" ] && source "$HOME/Library/Python/2.7/bin/virtualenvwrapper.sh"

# fix emoji and symbol pallete when it doesn't show up
function fix_emoji_palette {
    preferences_path="~/Library/Preferences/com.apple.HIToolbox.plist"

    if [ -e "$preferences_path" ]
    then
	rm "$preferences_path"
    fi
}
