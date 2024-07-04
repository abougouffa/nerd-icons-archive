;;; nerd-icons-archive.el --- Shows icons for each file in archive-mode and tar-mode -*- lexical-binding: t -*-

;; Copyright (C) 2024 Abdelhak Bougouffa <abougouffa@fedoraproject.org>

;; Author: Abdelhak Bougouffa <abougouffa@fedoraproject.org>
;; Version: 0.0.1
;; Package-Requires: ((emacs "28.1") (nerd-icons "0.0.1"))
;; URL: https://github.com/abougouffa/nerd-icons-archive
;; Keywords: files, icons, archive

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; To use this package, simply install and add this to your init.el
;; (require 'nerd-icons-archive)
;; (add-hook 'tar-mode-hook 'nerd-icons-archive-mode)

;; or use use-package:
;; (use-package nerd-icons-archive
;;   :hook
;;   (tar-mode . nerd-icons-archive-mode))

;; This package is inspired by
;; - `nerd-icons-dired': https://github.com/rainstormstudio/nerd-icons-dired


(require 'arc-mode)
(require 'tar-mode)
(require 'nerd-icons)

(defface nerd-icons-archive-dir-face
  '((t nil))
  "Face for the directory icon."
  :group 'nerd-icons-faces)

(defcustom nerd-icons-archive-v-adjust 0.01
  "The default vertical adjustment of the icon in the archive buffer."
  :group 'nerd-icons
  :type 'number)

(defcustom nerd-icons-archive-refresh-commands
  '(tar-new-entry tar-rename-entry tar-expunge archive-expunge archive-rename-entry)
  "Refresh the buffer icons when executing these commands."
  :group 'nerd-icons
  :type '(repeat function))

(defun nerd-icons-archive--add-overlay (pos string)
  "Add overlay to display STRING at POS."
  (let ((ov (make-overlay (1- pos) pos)))
    (overlay-put ov 'nerd-icons-archive-overlay t)
    (overlay-put ov 'after-string string)))

(defun nerd-icons-archive--overlays-in (beg end)
  "Get all nerd-icons-archive overlays between BEG to END."
  (cl-remove-if-not
   (lambda (ov)
     (overlay-get ov 'nerd-icons-archive-overlay))
   (overlays-in beg end)))

(defun nerd-icons-archive--overlays-at (pos)
  "Get nerd-icons-archive overlays at POS."
  (apply #'nerd-icons-archive--overlays-in `(,pos ,pos)))

(defun nerd-icons-archive--remove-all-overlays ()
  "Remove all `nerd-icons-archive' overlays."
  (save-restriction
    (widen)
    (mapc #'delete-overlay
          (nerd-icons-archive--overlays-in (point-min) (point-max)))))

(defun nerd-icons-archive--get-descriptor ()
  "Like `archive-get-descr' but simpler."
  (let ((no (archive-get-lineno)))
    (when (and (>= (point) archive-file-list-start)
               (< no (length archive-files)))
      (aref archive-files no))))

(defun nerd-icons-archive--next-line (&optional n)
  (let ((n (or n 1)))
    (pcase major-mode
      ('archive-mode
       (archive-next-line n))
      ('tar-mode
       (tar-next-line n)))))

(defun nerd-icons-archive--filename-at-pt ()
  (pcase major-mode
    ('archive-mode
     (when-let* ((descr (nerd-icons-archive--get-descriptor))
                 (name (archive--file-desc-int-file-name descr)))
       name))
    ('tar-mode
     (when-let* ((descr (ignore-errors (tar-current-descriptor)))
                 (name (tar-header-name descr)))
       name))))

(defun nerd-icons-archive--refresh ()
  "Display the icons of files in a archive buffer."
  (nerd-icons-archive--remove-all-overlays)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when-let ((name (nerd-icons-archive--filename-at-pt)))
        (let ((icon (if (string-suffix-p "/" name)
                        (nerd-icons-icon-for-dir name
                                                 :face 'nerd-icons-archive-dir-face
                                                 :v-adjust nerd-icons-archive-v-adjust)
                      (nerd-icons-icon-for-file name :v-adjust nerd-icons-archive-v-adjust)))
              (inhibit-read-only t))
          (if (member name '("." ".."))
              (nerd-icons-archive--add-overlay (nerd-icons-archive--move-to-filename) "  \t")
            (nerd-icons-archive--add-overlay (nerd-icons-archive--move-to-filename) (concat icon "\t")))))
      (nerd-icons-archive--next-line 1))))

(defun nerd-icons-archive--move-to-filename ()
  (pcase major-mode
    ('archive-mode
     (goto-char (line-beginning-position))
     (forward-char archive-file-name-indent)
     (point))
    ('tar-mode
     (goto-char (line-beginning-position))
     (goto-char (or (next-single-property-change (point) 'mouse-face) (point)))
     (point))))

(defun nerd-icons-archive--refresh-advice (fn &rest args)
  "Advice function for FN with ARGS."
  (let ((result (apply fn args))) ;; Save the result of the advised function
    (when nerd-icons-archive-mode
      (nerd-icons-archive--refresh))
    result)) ;; Return the result

(defun nerd-icons-archive--setup ()
  "Setup `nerd-icons-archive'."
  (setq-local tab-width 1)
  (dolist (cmd nerd-icons-archive-refresh-commands)
    (advice-add cmd :around #'nerd-icons-archive--refresh-advice))
  (nerd-icons-archive--refresh))

(defun nerd-icons-archive--teardown ()
  "Functions used as advice when redisplaying buffer."
  (dolist (cmd nerd-icons-archive-refresh-commands)
    (advice-remove cmd #'nerd-icons-archive--refresh))
  (nerd-icons-archive--remove-all-overlays))

;;;###autoload
(define-minor-mode nerd-icons-archive-mode
  "Display nerd-icons icon for each files in a archive buffer."
  :lighter " nerd-icons-archive-mode"
  (when (derived-mode-p 'archive-mode 'tar-mode)
    (if nerd-icons-archive-mode
        (nerd-icons-archive--setup)
      (nerd-icons-archive--teardown))))


(provide 'nerd-icons-archive)
;;; nerd-icons-archive.el ends here
