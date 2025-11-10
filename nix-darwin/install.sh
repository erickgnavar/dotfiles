# install nix from determinate
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
# respond no and then yes to install upstream nix instead of
# determinate nix
cd ~/dotfiles/nix-darwin/

# build a derivation with my config
# simple is the darwin configuration defined in flake.nix
nix --extra-experimental-features 'nix-command flakes' build ".#darwinConfigurations.simple.system"

# install homebrew because some apps will be installed from there
# instead of nix
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# switch system to this already built derivation
./result/sw/bin/darwin-rebuild switch --flake ".#simple"

# now we can run our helper install function
nixdarwnin_run_install
