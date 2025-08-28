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

(provide 'early-init)
;;; early-init.el ends here
