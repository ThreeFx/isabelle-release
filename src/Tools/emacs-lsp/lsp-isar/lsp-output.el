;;; -*- lexical-binding: t; -*-

;; Copyright (C) 2018-2019 Mathias Fleury

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and-or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Code:

(require 'isar-goal-mode)
(require 'lsp-decorations)

(require 'dom)
(eval-when-compile (require 'subr-x))

(defvar lsp-isar-state-buffer nil "Isabelle state buffer")
(defvar lsp-isar-output-buffer nil "Isabelle output buffer")

(defvar lsp-isar-proof-cases-content nil)

(define-inline remove-quotes-from-string (obj)
  (inline-letevals (obj)
    (inline-quote (string-remove-suffix "'" (string-remove-prefix "'" ,obj)))))


;; The function iterates over the HTML as parsed by the HTML
;; library. As a side effect, it fills the state buffer and the output
;; buffer with the correct faces.
;;
;; To shorten the code, we use the define-inline which is inlined
;; during compilation.
;;
;;
;; TODO
;;
;;   - find a big example to play with the recursive function to
;; optimise the code.
;;
;;   - benchmark if it makes sense to move the let for node and
;; children outside the cond in order to build a single jump table.
;;
;;   - TCO might be faster, but it is not trivial to express the
;; function that way. The mapconcat could be replaced by a side-effect
;; insertion on the buffer. propretize can become add-text-properties
;; with remembering of the initial point. Basically, the function
;; would have to have its own stack, making it harder to understand
;; and maintain.
;;
;;   - however, TCO might be required for very deep terms anyway.
;;
;;
;; The (cond ...) compiles down to a jump table, except for the
;; entries that contains (or (eq ...) (eq ...)). Therefore, I
;; duplicate entries.
;;
(define-inline lsp-isar--parse-output-print-all-children-in-output (content face)
  (inline-letevals (content face)
    (inline-quote
     (with-current-buffer lsp-isar-output-buffer
       (let ((inhibit-read-only t))
	 (let ((start-point (point)))
	   (mapc 'lsp-isar-parse-output (dom-children ,content))
	   (insert "\n")
	   (let ((ov (make-overlay start-point (point))))
	     (overlay-put ov 'face ,face))))))))

(define-inline lsp-isar--parse-output-print-last-children-in-output (content face)
  (inline-letevals (content face)
    (inline-quote
     (let ((inhibit-read-only t) (start-point (point)))
       (mapc 'lsp-isar-parse-output (dom-children ,content))
       (let ((ov (make-overlay start-point (point))))
	 (overlay-put ov 'face ,face))))))


(defun lsp-isar-parse-output (content)
  "The function iterates over the dynamic output generated by
Isabelle (after preprocessing), in order to generate a goal that
must be printed in Emacs with the syntax highlighting.

This is function is important for performance (not as critical as
the decorations), because goals can become arbitrary long. Remark
that I have not really tried to optimise it yet. Even if the
function is less critical, emacs is single threaded and all these
functions adds up. So any optimisation would help."
  ;;(message "content = %s" content)
  (cond
   ((eq content nil) nil)
   ((stringp content) (insert content))
   ((not (listp content))
    (message "unrecognised")
    (insert (format "%s" content)))
   (t
    (pcase (dom-tag content)
      ('html
       (mapc 'lsp-isar-parse-output (dom-children content)))
      ('xmlns nil)
      ('meta nil)
      ('link nil)
      ('xml_body nil)

      ('head
       (lsp-isar-parse-output (car (last (dom-children content)))))

      ('body
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('block
	  (insert (if (dom-attr content 'indent) " " ""))
	(mapc 'lsp-isar-parse-output (dom-children content)))

      ('class
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('pre
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('state_message
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('information_message
       (lsp-isar--parse-output-print-all-children-in-output
	content
	(cdr (assoc "dotted_information" lsp-isar-get-font))))

      ('tracing_message ;; TODO Proper colour
       (lsp-isar--parse-output-print-all-children-in-output
	content
	(cdr (assoc "dotted_information" lsp-isar-get-font))))

      ('warning_message
       (lsp-isar--parse-output-print-all-children-in-output
	content
	(cdr (assoc "dotted_warning" lsp-isar-get-font))))

      ('writeln_message
       (lsp-isar--parse-output-print-all-children-in-output
	content
	(cdr (assoc "dotted_writeln" lsp-isar-get-font))))

      ('error_message
       (lsp-isar--parse-output-print-all-children-in-output
	content
	(cdr (assoc "dotted_warning" lsp-isar-get-font))))

      ('text_fold
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('subgoal
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('span
       (insert (format "%s" (car (last (dom-children content))))))

      ('position
       (lsp-isar-parse-output (car (last (dom-children content)))))

      ('intensify
       (let ((start-point (point)))
	 (lsp-isar-parse-output (car (last (dom-children content))))
	 (add-text-properties start-point (point)
			      'font-lock-face (cdr (assoc "background_intensify" lsp-isar-get-font)))))

      ('keyword1
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_keyword1" lsp-isar-get-font))))

      ('keyword2
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_keyword2" lsp-isar-get-font))))

      ('keyword3
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_keyword3" lsp-isar-get-font))))

      ('keyword4
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_keyword4" lsp-isar-get-font))))

      ('fixed ;; this is used to enclose other variables
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('free
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_free" lsp-isar-get-font))))

      ('tfree
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_tfree" lsp-isar-get-font))))

      ('tvar
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_tvar" lsp-isar-get-font))))

      ('var
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_var" lsp-isar-get-font))))

      ('bound
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_bound" lsp-isar-get-font))))

      ('skolem
       (lsp-isar--parse-output-print-last-children-in-output content
							     (cdr (assoc "text_skolem" lsp-isar-get-font))))

      ('sendback ;; TODO handle properly
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('bullet
       (insert "•")
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('language
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('literal
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('delimiter
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('entity
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('paragraph
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('item
       ;;(message "%s" (mapconcat 'lsp-isar-parse-output (dom-children content) ""))
       (mapc 'lsp-isar-parse-output (dom-children content))
       (insert "\n"))

      ('break
       (let ((children (mapcar 'remove-quotes-from-string (dom-children content))))
	 (insert (if (dom-attr content 'width) " " ""))
	 (insert (if (dom-attr content 'line) "\n" ""))
	 (mapc 'lsp-isar-parse-output children)))

      ('xml_elem
       (mapc 'lsp-isar-parse-output (dom-children content)))

      ('sub
       (insert (format "\\<^sub>%s" (car (last (dom-children content))))))

      ('sup
       (insert (format "\\<^sup>%s" (car (last (dom-children content))))))

      (_
       (if (listp (dom-tag content))
	   (progn
	     (message "unrecognised node %s" (dom-tag content))
	     (insert (format "%s" (dom-tag content)))
	     (mapc 'lsp-isar-parse-output (dom-children content)))
	 (progn
	   (message "unrecognised content %s; node is: %s; string: %s %s"
		    content (dom-tag content) (stringp (dom-tag content)) (listp content))
	   (insert (format "%s" (dom-tag content))))))))))

(defun replace-regexp-all-occs (REGEXP TO-STRING)
  "replace-regexp as indicated in the help"
  (goto-char (point-min))
  (while (re-search-forward REGEXP nil t)
    (replace-match TO-STRING nil nil)))


(defun lsp-isar--update-state-and-output-buffer (content)
  "Updates state and output buffers"
  (setq parsed-content nil)
  (let ((inhibit-read-only t))
    (save-excursion
      (with-current-buffer lsp-isar-output-buffer
	(setf (buffer-string) ""))
      (with-current-buffer lsp-isar-state-buffer
	(setq parsed-content
	      (with-temp-buffer
		(if content
		    (progn
		      (insert "$")
		      (insert content)
		      ;; Isabelle's HTML and emacs's HMTL disagree, so
		      ;; we preprocess the output.

		      ;; remove line breaks at beginning
		      (replace-regexp-all-occs "\\$\n*<body>\n" "<body>")

		      ;; make sure there is no "$" left
		      (replace-regexp-all-occs "\\$" "")

		      ;; protect spaces and line breaks
		      (replace-regexp-all-occs "\n\\( *\\)"
					       "<break line = 1>'\\1'</break>")
		      (replace-regexp-all-occs "\\(\\w\\)>\\( *\\)<"
					       "\\1><break>'\\2'</break><")

		      ;;(message (buffer-string))
		      ;;(message "%s"(libxml-parse-html-region  (point-min) (point-max)))
	              (setq parsed-content (libxml-parse-html-region  (point-min) (point-max)))))))

	(setf (buffer-string) "")
	(lsp-isar-parse-output parsed-content)
	(goto-char (point-min))
	(ignore-errors
	  (search-forward "Proof outline with cases:") ;; TODO this should go to lsp-isar-parse-output
	  (setq lsp-isar-proof-cases-content (buffer-substring (point) (point-max))))))))

(defun lsp-isar-initialize-output-buffer ()
  (setq lsp-isar-state-buffer (get-buffer-create "*lsp-isar-state*"))
  (setq lsp-isar-output-buffer (get-buffer-create "*lsp-isar-output*"))
  (save-excursion
    (with-current-buffer lsp-isar-state-buffer
      (read-only-mode t)
      (isar-goal-mode))
    (with-current-buffer lsp-isar-output-buffer
      (read-only-mode t)
      (isar-goal-mode))))

(defun lsp-isar-insert-cases ()
  "insert the last seen outline"
  (interactive)
  (insert lsp-isar-proof-cases-content))


(modify-coding-system-alist 'file "*lsp-isar-output*" 'utf-8-auto)

(provide 'lsp-output)
