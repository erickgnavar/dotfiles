;;; init.el --- bootstrap file to load config from bootstrap.org
;;; Commentary:
;;; Code:
(require 'package)

(setq package-enable-at-startup nil)

(add-to-list 'package-archives
             '("melpa" . "http://melpa.org/packages/") t)
(add-to-list 'package-archives
             '("org" . "http://orgmode.org/elpa/") t)

(package-initialize)

;; Install use-package
(when (not package-archive-contents)
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

(require 'diminish)
(require 'bind-key)

;; read bootstrap.org and load emacs-lisp code
(org-babel-load-file (expand-file-name "~/.emacs.d/bootstrap.org"))

(provide 'init.el)
;;; init.el ends here
