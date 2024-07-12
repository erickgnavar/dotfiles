;;; early-init.el --- early init code -*- lexical-binding: t -*-
;;; Commentary:

;; Disable menu bar only on linux, because it will be using a tiling window manager
(when (string-equal system-type "gnu/linux")
  (menu-bar-mode -1))

;;; Code:
;; Hide vertical scroll bar
(scroll-bar-mode -1)

;; Disable package.el in favor of straight.el
(setq package-enable-at-startup nil)

;; Hide toolbar
(tool-bar-mode -1)

(provide 'early-init)
;;; early-init.el ends here
