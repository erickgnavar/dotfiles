;;; init.el --- bootstrap file to load config from bootstrap.org
;;; Commentary:
;;; Code:
(require 'package)

(setq package-enable-at-startup nil)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

;; Install use-package
(when (not package-archive-contents)
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

;; setup zsh as a default shell when is available
(let ((zsh-path (executable-find "zsh")))
  (when zsh-path
    (setq shell-file-name zsh-path)))

(require 'bind-key)

(use-package diminish
  :ensure t)

(use-package delight
  :ensure t)

(use-package quelpa-use-package
  :ensure t
  :custom
  (quelpa-update-melpa-p nil)
  :config
  (quelpa-use-package-activate-advice))

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
             (setq gc-cons-threshold 16777216
                   gc-cons-percentage 0.1
                   file-name-handler-alist last-file-name-handler-alist)))

(provide 'init.el)
;;; init.el ends here
