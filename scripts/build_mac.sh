#!/bin/bash -

CWD=$(pwd)

if [ -z "$1" ]
then
    echo "Please provide the directory where emacs source is located"
    exit 1
fi

EMACS_REPO_DIR=$1

if [ ! -d "$EMACS_REPO_DIR" ]
then
    echo "$EMACS_REPO_DIR is not a valid directory"
    exit 1
fi

cd "$EMACS_REPO_DIR" || exit

# clean past build data
git clean -fdx

set -o nounset

make clean

echo "Making sure all requirements are installed..."

# harfbuzz adds support for ligatures, this is required by ligature.el package
brew install autoconf automake libxml2 jansson gnutls cmake librsvg texinfo libgccjit

echo "Seting up variables..."

PKG_CONFIG_PATH="$(brew --prefix libxml2)/lib/pkgconfig"

export ${"$PKG_CONFIG_PATH"}

make configure
./configure --with-ns --with-xwidgets --with-tree-sitter --with-native-compilation=aot
make -j install

echo "Done!"

# copy better icons that fits Big Sur design
cp "$CWD/Emacs.icns" nextstep/Emacs.app/Contents/Resources/

echo "Move compiled application into Applications folder?"
read -r answer

# we ask for confirmation so we can check compilation stdout before replacing a working version of emacs
if [ "$answer" != "${answer#[Yy]}" ] ; then
    echo "Compiled application was moved into Applications folder"
    # Copy app in Applications folder
    cp -rf nextstep/Emacs.app /Applications/
else
    echo "Compiled application wasn't moved"
    exit 1
fi

cd - || exit
