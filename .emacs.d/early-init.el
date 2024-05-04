;;; early-init.el --- early init code -*- lexical-binding: t -*-
;;; Commentary:

;;; Code:
;; Hide vertical scroll bar
(scroll-bar-mode -1)

;; Disable package.el in favor of straight.el
(setq package-enable-at-startup nil)

;; Hide toolbar
(tool-bar-mode -1)

(provide 'early-init)
;;; early-init.el ends here
