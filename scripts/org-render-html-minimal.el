(require 'package)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

(package-refresh-contents)

;; this is required to highlight code blocks properly
(package-install 'htmlize)

(require 'org)

;; Org 9.6+ refuses to download remote SETUPFILE resources in batch
;; mode (no minibuffer to prompt). Allow the readtheorg theme setupfile
;; explicitly so its #+HTML_HEAD <link> tags get injected into the HTML.
(add-to-list 'org-safe-remote-resources
             "https://raw\\.githubusercontent\\.com/fniessen/org-html-themes/.*")

(require 'htmlize)

;; For some reason the default value `inline-css' doesn't apply syntax highlighting correctly
;; in the resulting html file so we need to change the value to `css'
(setq org-html-htmlize-output-type 'css)
