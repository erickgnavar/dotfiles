#!/bin/sh

# read the docs based theme
echo "#+SETUPFILE: https://raw.githubusercontent.com/fniessen/org-html-themes/master/org/theme-readtheorg.setup" > index.org
cat ../.emacs.d/bootstrap.org >> index.org

emacs index.org --batch -Q --load org-render-html-minimal.el -f org-html-export-to-html --kill

# output will be the directory uploaded to the render repository so we have to put all the resulting files inside that folder
mkdir output
mv index.html output/
