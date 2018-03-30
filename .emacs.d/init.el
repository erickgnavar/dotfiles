;;; init.el --- bootstrap file to load config from bootstrap.org
;;; Commentary:
;;; Code:
(require 'package)

(setq package-enable-at-startup nil)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")
                         ("org" . "https://orgmode.org/elpa/")))

(package-initialize)

;; Install use-package
(when (not package-archive-contents)
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

(require 'bind-key)

(use-package diminish
  :ensure t)

(use-package delight
  :ensure t)

;; Always follow symlinks, used to avoid emacs ask when open org conf file
(setq vc-follow-symlinks t)

;; read bootstrap.org and load emacs-lisp code
(org-babel-load-file (expand-file-name "~/.emacs.d/bootstrap.org"))

(provide 'init.el)
;;; init.el ends here
