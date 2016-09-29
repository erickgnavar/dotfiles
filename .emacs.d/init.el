;;; init.el --- Emacs config file
;;; Commentary:
;;; Code:
(require 'package)

(add-to-list 'package-archives
             '("melpa" . "http://melpa.org/packages/") t)
(add-to-list 'package-archives
             '("org" . "http://orgmode.org/elpa/") t)

(package-initialize)

(when (not package-archive-contents)
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))
(require 'diminish)
(require 'bind-key)

;; Base config
(menu-bar-mode 1)
(setq inhibit-startup-message t)
;; Hide the bell in the center of screen
(setq ring-bell-function 'ignore)
(column-number-mode t)
(global-hl-line-mode 1)
(set-frame-font "Monaco 12")
(global-set-key (kbd "C-x -") 'text-scale-decrease)
(global-set-key (kbd "C-x =") 'text-scale-increase)
(global-set-key (kbd "C-x +") 'text-scale-increase)
;; Fix size of scroll
(setq scroll-step 1
      scroll-conservatively  10000)
;; Avoid close emacs by mistake
(global-unset-key (kbd "C-x C-c"))

(defalias 'yes-or-no-p 'y-or-n-p)
(defalias 'run-elisp 'ielm)

(use-package better-defaults
  :ensure t)

(use-package pbcopy
  :ensure t)

(use-package zerodark-theme
  :ensure t
  :config
  (load-theme 'zerodark t))

(use-package spaceline
  :ensure t
  :config
  (require 'spaceline-config)
  ;; default separator render fails
  (defvar powerline-default-separator 'box)
  (setq powerline-default-separator 'box)
  (spaceline-spacemacs-theme)
  (spaceline-helm-mode)
  ;; vim mode colors
  (setq spaceline-highlight-face-func 'spaceline-highlight-face-evil-state))

(use-package writeroom-mode
  :ensure t)

;; Load PATH environment
(use-package exec-path-from-shell
  :ensure t
  :config
  (when (memq window-system '(mac ns))
    (exec-path-from-shell-initialize)))

(use-package restclient
  :ensure t)

(use-package flycheck
  :ensure t
  :diminish ""
  :config
  (global-flycheck-mode))

(use-package company
  :ensure t
  :config
  (global-company-mode)
  (setq company-idle-delay 0.1)
  (setq company-tooltip-limit 10)
  (setq company-minimum-prefix-length 3)
  (add-hook 'after-init-hook 'global-company-mode))

(use-package git-gutter
  :ensure t
  :diminish ""
  :config
  (global-git-gutter-mode)
  (git-gutter:linum-setup))

(use-package evil
  :ensure t
  :config
  (evil-mode 1)
  (add-hook 'prog-mode-hook
            (lambda ()
              (modify-syntax-entry ?_ "w")
              (hs-minor-mode 1)))
  (use-package evil-nerd-commenter
    :ensure t
    :config
    (evilnc-default-hotkeys)
    (global-set-key (kbd "C-\-") 'evilnc-comment-operator))
  (use-package evil-surround
    :ensure t
    :config
    (global-evil-surround-mode 1))
  (use-package evil-leader
    :ensure t
    :config
    (global-evil-leader-mode)
    (evil-leader/set-key
	"f" 'find-file
	"a" 'helm-ag-project-root
	"e" 'my/find-file-in-project
	"b" 'helm-buffers-list
	"n" 'evil-buffer-new
	"y" 'helm-show-kill-ring
	"SPC" 'helm-M-x
	"m" 'ace-jump-mode
	"l" 'linum-mode
	"s" 'my/toggle-spanish-characters
	"w" 'my/toggle-maximize
	"g" 'magit-status
	"k" 'kill-buffer)
    (evil-leader/set-key-for-mode 'python-mode "d" 'elpy-goto-definition)))

(setq python-shell-completion-native-enable nil)

(use-package ace-jump-mode
  :ensure t)

(use-package expand-region
  :ensure t
  :config
  ;; unbind default keymap for "_", the default is: evil-next-line-1-first-non-blank
  (define-key evil-motion-state-map (kbd "_") nil)
  (define-key evil-normal-state-map (kbd "_") 'er/contract-region)
  (define-key evil-normal-state-map (kbd "+") 'er/expand-region))

(define-key evil-normal-state-map (kbd "SPC") 'hs-toggle-hiding)

(use-package gist
  :ensure t)

(use-package org
  :ensure t
  :config
  (setq org-clock-persist 'history)
  (org-clock-persistence-insinuate)
  (use-package ox-twbs
    :ensure t)
  (use-package ob-restclient
    :ensure t)
  (use-package htmlize
    :ensure t)
  (org-babel-do-load-languages 'org-babel-load-languages
                               '((python . t)
                                 (sh . t)
                                 (lisp . t)
                                 (sql . t)
                                 (restclient . t)
                                 (emacs-lisp . t))))

(use-package helm
  :ensure t
  :diminish ""
  :config
  (require 'helm-config)
  (helm-mode 1)
  (define-key helm-map (kbd "<tab>") 'helm-execute-persistent-action)
  (setq helm-split-window-in-side-p t)
  (add-to-list 'display-buffer-alist
               '("\\`\\*helm.*\\*\\'"
                 (display-buffer-in-side-window)
                 (inhibit-same-window . t)
                 (window-height . 0.4)))
  (use-package helm-ag
    :ensure t))

(use-package magit
  :ensure t
  :config
  (add-hook 'magit-blame-mode-hook
            (lambda ()
              (evil-emacs-state))))

(use-package neotree
  :ensure t
  :config
  (global-set-key [f3] 'neotree-toggle)
  (defvar neo-fit-to-contents t)
  (setq neo-fit-to-contents t)
  (setq neo-theme (quote classic))
  (setq neo-vc-integration (quote (face)))
  (evil-set-initial-state 'neotree-mode 'emacs)
  (add-hook 'neotree-mode-hook
            (lambda ()
              (evil-emacs-state)
              (local-set-key (kbd "C-c C-r") 'neotree-rename-node))))

(use-package yaml-mode
  :ensure t)

(use-package markdown-mode
  :ensure t)

(use-package projectile
  :ensure t
  :config
  (projectile-global-mode)
  (setq projectile-completion-system 'helm)
  (add-hook 'projectile-after-switch-project-hook
            (lambda ()
              (my/setup-eslint))))

(use-package projectile-direnv
  :ensure t
  :config
  (add-hook 'projectile-mode-hook 'projectile-direnv-export-variables))

(use-package editorconfig
  :ensure t
  :config
  (editorconfig-mode 1))

(use-package rust-mode
  :ensure t
  :config
  (use-package cargo
    :ensure t
    :config
    (add-hook 'rust-mode-hook
              (lambda ()
                (cargo-minor-mode t)
                (define-key cargo-minor-mode-map "\C-c\C-t" 'cargo-process-test)
                (define-key cargo-minor-mode-map "\C-c\C-b" 'cargo-process-build)
                (define-key cargo-minor-mode-map "\C-c\C-r" 'cargo-process-run)))))

(use-package elpy
  :ensure t
  :config
  (elpy-enable)
  (when (require 'flycheck nil t)
    (setq elpy-modules (delq 'elpy-module-flymake elpy-modules))
    (add-hook 'elpy-mode-hook 'flycheck-mode))
  (setq elpy-test-django-runner-command '("./manage.py" "test" "--keepdb"))
  (add-hook 'elpy-mode-hook
            (lambda ()
              (highlight-indentation-mode -1) ; Remove vertical line
              (my/fold-buffer-when-is-too-big 100))))

(use-package emmet-mode
  :ensure t)

(use-package web-mode
  :ensure t
  :mode (("\\.html\\'" . web-mode)
         ("\\.html.eex\\'" . web-mode))
  :config
  (setq web-mode-enable-current-element-highlight t)
  (setq web-mode-enable-current-column-highlight t)
  (add-hook 'web-mode-hook 'emmet-mode))

(use-package rainbow-mode
  :ensure t)

(use-package autopair
  :ensure t
  :diminish ""
  :config
  (autopair-global-mode))

(use-package yasnippet
  :ensure t
  :diminish ""
  :config
  (yas-global-mode 1))

(use-package elixir-mode
  :ensure t)

(use-package alchemist
  :ensure t
  :config
  (setq alchemist-mix-env "dev")
  (add-hook 'alchemist-mode-hook
            (lambda ()
              (local-set-key (kbd "C-c C-t") 'alchemist-mix-test-this-buffer))))

(use-package lfe-mode
  :ensure t
  :config
  (defun lfe-eval-buffer ()
    "Send current buffer to inferior LFE process."
    (interactive)
    (lfe-eval-region (point-min) (point-max) nil))
  (define-key lfe-mode-map "\C-c\C-c" 'lfe-eval-buffer))

(use-package elm-mode
  :ensure t
  :config
  (add-hook 'elm-mode-hook #'elm-oracle-setup-completion)
  (add-to-list 'company-backends 'company-elm))

(use-package haskell-mode
  :ensure t)

(use-package stack-mode
  :ensure t
  :config
  (add-hook 'haskell-mode-hook 'stack-mode))

(diminish 'undo-tree-mode)
(diminish 'hs-minor-mode)

;; Use ESC key instead C-g to close and abort
;; copied from somewhere
(defun minibuffer-keyboard-quit ()
  "Abort recursive edit.
In Delete Selection mode, if the mark is active, just deactivate it;
then it takes a second \\[keyboard-quit] to abort the minibuffer."
  (interactive)
  (if (and delete-selection-mode transient-mark-mode mark-active)
    (setq deactivate-mark  t)
    (when (get-buffer "*Completions*") (delete-windows-on "*Completions*"))
    (abort-recursive-edit)))

(define-key evil-normal-state-map [escape] 'keyboard-quit)
(define-key evil-visual-state-map [escape] 'keyboard-quit)
(define-key minibuffer-local-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-isearch-map [escape] 'minibuffer-keyboard-quit)
(global-set-key [escape] 'evil-exit-emacs-state)

;; Custom functions

(defun my/find-file-in-project ()
  "Custom find file function."
  (interactive)
  (if (projectile-project-p)
      (projectile-find-file)
      (helm-for-files)))

(defun my/fold-buffer-when-is-too-big (max-lines)
  "Fold buffer is max lines if grater than as MAX-LINES."
  (if (> (count-lines (point-min) (point-max)) max-lines)
      (hs-hide-all)))

(defun my/setup-eslint ()
  "If eslint is installed locally configure flycheck to use it."
  (let ((local-eslint (concat (projectile-project-root) "node_modules/.bin/eslint")))
    (setq flycheck-javascript-eslint-executable (and (file-exists-p local-eslint) local-eslint))))

(defun my/toggle-maximize ()
  "Toggle maximization of current window."
  (interactive)
  (let ((register ?w))
    (if (eq (get-register register) nil)
      (progn
        (set-register register (current-window-configuration))
        (delete-other-windows))
      (progn
        (set-window-configuration (get-register register))
        (set-register register nil)))))

(defun my/toggle-spanish-characters ()
  "Enable/disable alt key to allow insert spanish characters."
  (interactive)
  (if (eq ns-alternate-modifier 'meta)
      (setq ns-alternate-modifier nil)
      (setq ns-alternate-modifier 'meta)))

(provide 'init)
;;; init.el ends here
