#!/bin/sh -e

mkdir -p $HOME/.emacs.d/straight/versions/
ls -ls
cp .emacs.d/bootstrap.org $HOME/.emacs.d/
cp .emacs.d/init.el $HOME/.emacs.d/
cp .emacs.d/fira-code-mode.el $HOME/.emacs.d/
cp .emacs.d/straight/versions/default.el $HOME/.emacs.d/straight/versions/
# emacs -Q --batch -L . --eval "(setq byte-compile-error-on-warn t)" -f batch-byte-compile $HOME/.emacs.d/init.el
emacs -Q --batch -L . --eval "(setq byte-compile-error-on-warn t)" -f batch-byte-compile $HOME/.emacs.d/init.el
