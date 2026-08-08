(require 'package)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

;; This is required to highlight code blocks properly.
(package-refresh-contents)
(package-install 'htmlize)

(require 'htmlize)
(require 'org)

(defconst dotfiles-html-head
  (let ((stylesheet
         (expand-file-name "config-site.css"
                           (file-name-directory load-file-name))))
    (with-temp-buffer
      (insert-file-contents stylesheet)
      (concat "<style>\n" (buffer-string) "</style>"))))

(defconst dotfiles-html-scripts
  "<script>
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('pre.src').forEach(block => {
    const button = document.createElement('button');
    button.className = 'copy';
    button.type = 'button';
    button.textContent = 'Copy';
    button.setAttribute('aria-label', 'Copy code snippet');
    button.addEventListener('click', async () => {
      await navigator.clipboard.writeText(block.textContent);
      button.textContent = 'Copied';
      setTimeout(() => button.textContent = 'Copy', 1200);
    });
    block.parentElement.prepend(button);
  });
});
</script>")

;; Keep source highlighting in CSS classes and use the same visual language as
;; the generated dotfiles index instead of an external Org theme.
(setq org-export-time-stamp-file nil
      org-html-htmlize-output-type 'css
      org-html-head dotfiles-html-head
      org-html-head-extra dotfiles-html-scripts
      org-html-head-include-default-style nil
      org-html-head-include-scripts nil)
