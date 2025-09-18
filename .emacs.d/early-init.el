;;; early-init.el --- early init code -*- lexical-binding: t -*-
;;; Commentary:

;; only show menu bar when running Emacs with GUI on macOS
(unless (and (string-equal system-type "darwin") (display-graphic-p))
  (menu-bar-mode -1))

;;; Code:
;; Hide vertical scroll bar
(scroll-bar-mode -1)

;; Disable package.el in favor of elpaca.el
(setq package-enable-at-startup nil)

;; Hide toolbar
(tool-bar-mode -1)

;; Set transparency
(set-frame-parameter nil 'alpha 95)

;; Change GC config to speed up startup time
;; Copied from https://github.com/hlissner/doom-emacs/issues/310#issuecomment-354424413
(defvar last-file-name-handler-alist file-name-handler-alist)
(setq gc-cons-threshold 402653184
      gc-cons-percentage 0.6
      file-name-handler-alist nil)

(defun my/restore-gc-params ()
  "Setup GC with a bigger value which is required for lsp to work properly."
  (setq gc-cons-threshold (* 100 1024 1024)
        gc-cons-percentage 0.1
        file-name-handler-alist last-file-name-handler-alist))

;; Restore GC previous config
(add-hook 'emacs-startup-hook 'my/restore-gc-params)

(provide 'early-init)
;;; early-init.el ends here
