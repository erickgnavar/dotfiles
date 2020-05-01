;;; init.el --- bootstrap file to load config from bootstrap.org
;;; Commentary:
;;; Code:
(require 'package)

(defvar bootstrap-version)

(defvar straight-use-package-by-default t)

;; Install straight.el
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Install use-package using straight
(straight-use-package 'use-package)

;; setup zsh as a default shell when is available
(let ((zsh-path (executable-find "zsh")))
  (when zsh-path
    (setq shell-file-name zsh-path)))

(require 'bind-key)

(use-package diminish
  :ensure t)

(use-package delight
  :ensure t)

;; Always follow symlinks, used to avoid emacs ask when open org conf file
(setq vc-follow-symlinks t)

;; Change GC config to speed up startup time
;; Copied from https://github.com/hlissner/doom-emacs/issues/310#issuecomment-354424413
(defvar last-file-name-handler-alist file-name-handler-alist)
(setq gc-cons-threshold 402653184
      gc-cons-percentage 0.6
      file-name-handler-alist nil)

;; read bootstrap.org and load emacs-lisp code
(org-babel-load-file (expand-file-name "~/.emacs.d/bootstrap.org"))

;; Restore GC previous config
(add-hook 'emacs-startup-hook
          '(lambda ()
             ;; a bigger value is required for lsp to work properly
             (setq gc-cons-threshold (* 100 1024 1024)
                   gc-cons-percentage 0.1
                   file-name-handler-alist last-file-name-handler-alist)))

(provide 'init.el)
;;; init.el ends here
