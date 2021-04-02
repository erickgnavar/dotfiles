(require 'package)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

(package-refresh-contents)

;; this is required to highlight code blocks properly
(package-install 'htmlize)

(require 'org)

(require 'htmlize)

;; For some reason the default value `inline-css' doesn't apply syntax highlighting correctly
;; in the resulting html file so we need to change the value to `css'
(setq org-html-htmlize-output-type 'css)
