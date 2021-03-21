#!/bin/bash -

CWD=`(pwd)`

if [ -z $1 ]
then
    echo "Please provide the directory where emacs source is located"
    exit 1
fi

EMACS_REPO_DIR=$1

if [ ! -d $EMACS_REPO_DIR ]
then
    echo "$EMACS_REPO_DIR is not a valid directory"
    exit 1
fi

cd $EMACS_REPO_DIR

# clean past build data
git clean -fdx

set -o nounset

make clean

echo "Making sure all requirements are installed..."

brew install autoconf automake libxml2 jansson gnutls cmake librsvg texinfo

echo "Seting up variables..."

export PKG_CONFIG_PATH="$(brew --prefix libxml2)/lib/pkgconfig"

make configure
./configure --with-ns
make install

echo "Done!"

# copy better icons that fits Big Sur design
cp $CWD/Emacs.icns nextstep/Emacs.app/Contents/Resources/

open -R nextstep/Emacs.app

cd -
