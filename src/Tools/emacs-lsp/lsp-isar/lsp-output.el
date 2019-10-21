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
(defvar lsp-isar-proof-timer nil "Current timer rendering the HTML")
(defcustom lsp-isar-maximal-time 3 "Maximal time in seconds printing can take. Use nil for infinity")
(defvar lsp-isar--last-start nil "Last start time in seconds")
(defvar lsp-isar--previous-goal nil "previous outputted goal")
(defcustom lsp-isar-time-before-printing-goal 0.3 "Time before printing goal. Use nil to avoid printing goals.")

(define-error 'abort-rendering "Abort the rendering of the state and output buffer")

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
;;   - find a proper profiling library.
;;
;;
;;
;; The (cond ...) compiles down to a jump table, except for the
;; entries that contains (or (eq ...) (eq ...)). Therefore, I
;; duplicate entries.
;;
;;
;; RESULT OF SOME INVESTIGATION
;;
;;   - parsing the goal is not slow during testing but can beome a
;; huge issue on Isabelle theories. And profiling in emacs is as usual
;; entirely useless.
;;
;;  - the goal has to be simplified (or preprocessed outside of the
;; emacs main thread), but it is not clear how to achieve this.
;;
;;
;; To reduce the overhead of printing (especially when the output
;; contains an error), we delay the printing, such that we can cancel
;; it if another newer version of the goal is coming.
;;
(defun lsp-isar-parse-output (contents)
  "The function iterates over the dynamic output generated by
Isabelle (after preprocessing), in order to generate a goal that
must be printed in Emacs with the syntax highlighting.

This is function is important for performance (not as critical as
the decorations), because goals can become arbitrary long. Remark
that I have not really tried to optimise it yet. Even if the
function is less critical, emacs is single threaded and all these
functions adds up. So any optimisation would help."
  (while contents
    (let ((content (pop contents)))
      ;; (message "content = %s" content)
      (cond
	((and lsp-isar-maximal-time (> (- (time-to-seconds) lsp-isar--last-start) lsp-isar-maximal-time))
	 (signal 'abort-rendering nil))
	((eq content nil) nil)
	((eq content 'html) nil)
	((stringp content) (insert content))
	((not (listp content))
	 (message "unrecognised %s"
		  content)
	 (insert (format "%s" content)))
	(t
	 (pcase (dom-tag content)
	   ('lsp-isar-fontification
	    (let ((start-point (dom-attr content 'start-point))
		  (face (dom-attr content 'face)))
	      (let ((ov (make-overlay start-point (point))))
		(overlay-put ov 'face face))))
	   ('html
	    (setq contents (append (dom-children content) contents)))
	   ('xmlns nil)
	   ('meta nil)
	   ('link nil)
	   ('xml_body nil)
	   ('path nil)

	   ('head
	    (push (car (last (dom-children content))) contents))

	   ('body
	    (setq contents (append (dom-children content) contents)))

	   ('block
	       (insert (if (dom-attr content 'indent) " " ""))
	     (setq contents (append (dom-children content) contents)))

	   ('class
	    (setq contents (append (dom-children content) contents)))

	   ('pre
	    (setq contents (append (dom-children content) contents)))

	   ('state_message
	    (setq contents (append (dom-children content) contents)))

	   ('information_message
	    (set-buffer lsp-isar-output-buffer)
	    (let ((start-point (point)) (face (cdr (assoc "dotted_information" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('tracing_message ;; TODO Proper colour
	    (set-buffer lsp-isar-output-buffer)
	    (let ((start-point (point)) (face (cdr (assoc "dotted_information" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('warning_message
	    (set-buffer lsp-isar-output-buffer)
	    (let ((start-point (point)) (face (cdr (assoc "dotted_warning" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('writeln_message
	    (set-buffer lsp-isar-output-buffer)
	    (let ((start-point (point)) (face (cdr (assoc "dotted_writeln" lsp-isar-get-font))))
	      (push (dom-node 'break `(('line . 1)) "\n") contents)
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('error_message
	    (set-buffer lsp-isar-output-buffer)
	    (let ((start-point (point)) (face (cdr (assoc "text_overview_error" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('text_fold
	    (setq contents (append (dom-children content) contents)))

	   ('subgoal
	    (set-buffer lsp-isar-state-buffer)
	    (setq contents (append (dom-children content) contents)))

	   ('span
	    (insert (format "%s" (car (last (dom-children content))))))

	   ('position
	    (push (car (last (dom-children content))) contents))

	   ('intensify
	    (let ((start-point (point)) (face (cdr (assoc "background_intensify" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('keyword1
	    (let ((start-point (point)) (face (cdr (assoc "text_keyword1" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('keyword2
	    (let ((start-point (point)) (face (cdr (assoc "text_keyword2" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('keyword3
	    (let ((start-point (point)) (face (cdr (assoc "text_keyword3" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('keyword4
	    (let ((start-point (point)) (face (cdr (assoc "text_keyword4" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('fixed ;; this is used to enclose other variables
	    (setq contents (append (dom-children content) contents)))

	   ('free
	    (let ((start-point (point)) (face (cdr (assoc "text_free" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('tfree
	    (let ((start-point (point)) (face (cdr (assoc "text_tfree" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('tvar
	    (let ((start-point (point)) (face (cdr (assoc "text_tvar" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('var
	    (let ((start-point (point)) (face (cdr (assoc "text_var" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('bound
	    (let ((start-point (point)) (face (cdr (assoc "text_bound" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('skolem
	    (let ((start-point (point)) (face (cdr (assoc "text_skolem" lsp-isar-get-font))))
	      (push (dom-node 'lsp-isar-fontification `((start-point . ,start-point) (face . ,face)) nil) contents)
	      (setq contents (append (dom-children content) contents))))

	   ('sendback ;; TODO handle properly
	    (setq contents (append (dom-children content) contents)))

	   ('bullet
	    (insert "•")
	    (setq contents (append (dom-children content) contents)))

	   ('language
	    (setq contents (append (dom-children content) contents)))

	   ('literal
	    (setq contents (append (dom-children content) contents)))

	   ('delimiter
	    (setq contents (append (dom-children content) contents)))

	   ('entity
	    (setq contents (append (dom-children content) contents)))

	   ('paragraph
	    (setq contents (append (dom-children content) contents)))

	   ('dynamic_fact
	    (setq contents (append (dom-children content) contents)))

	   ('item
	    ;;(message "%s" (mapconcat 'lsp-isar-parse-output (dom-children content) ""))
	    (setq contents (append (dom-children content) contents))) ;; TODO line break

	   ('break
	    (let ((children (mapcar 'remove-quotes-from-string (dom-children content))))
	      (insert (if (dom-attr content 'width) " " ""))
	      (insert (if (dom-attr content 'line) "\n" ""))
	      (mapc 'insert children)))

	   ('xml_elem
	    (setq contents (append (dom-children content) contents)))

	   ('sub ;; Heuristically find the difference between sub and bsub...esub
	    (let ((children (dom-children content)))
	      (if (and
		   (not (cdr children))
		   (stringp (car children)))
		  (insert (format "\\<^sub>%s" (car children)))
		(progn
		  (insert "\\<^bsub>")
		  (push "\\<^esub>" contents))
		(setq contents (append children contents)))))

	   ('sup ;; Heuristically find the difference between sup and bsup...esup
	    (let ((children (dom-children content)))
	      (if (and
		   (not (cdr children))
		   (stringp (car children)))
		  (insert (format "\\<^sup>%s" (car children)))
		(progn
		  (insert "\\<^bsup>")
		  (push "\\<^esup>" contents))
		(setq contents (append children contents)))))

	   (_
	    (if (listp (dom-tag content))
		(progn
		  (message "unrecognised node %s" (dom-tag content))
		  (insert (format "%s" (dom-tag content)))
		  (mapc 'lsp-isar-parse-output (dom-children content)))
	      (progn
		(message "unrecognised content %s; node is: %s; string: %s %s"
			 content (dom-tag content) (stringp (dom-tag content)) (listp content))
		(insert (format "%s" (dom-tag content))))))))))))

(defun replace-regexp-all-occs (REGEXP TO-STRING)
  "replace-regexp as indicated in the help"
  (goto-char (point-min))
  (while (re-search-forward REGEXP nil t)
    (replace-match TO-STRING nil nil)))

(defun lsp-isar-update-goal-without-deadline ()
    "Updates the goal without time limit"
  (interactive)
  (setq old-timeout lsp-isar-maximal-time)
  (setq lsp-isar-maximal-time nil)
  (lsp-isar--update-state-and-output-buffer lsp-isar--previous-goal)
  (setq lsp-isar-maximal-time old-timeout))


(defun lsp-isar--update-state-and-output-buffer (content)
  "Updates state and output buffers"
  (condition-case nil
      (let ((parsed-content nil))
	(setq lsp-isar--previous-goal content)
	(save-excursion
	  (with-current-buffer lsp-isar-output-buffer
	    (read-only-mode -1)
	    (setf (buffer-string) ""))
	  (with-temp-buffer
	    (if content
		(progn
		  (insert "$")
		  (insert content)
		  ;; (message (buffer-string))
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
		  ;;(replace-regexp-all-occs "\\(\\w\\)>\"" "\\1>\\\"")

		  ;;(message (buffer-string))
		  ;;(message "%s"(libxml-parse-html-region  (point-min) (point-max)))
		  (setq parsed-content (libxml-parse-html-region (point-min) (point-max))))))
	  (with-current-buffer lsp-isar-state-buffer
	    (let ((inhibit-read-only t))
	      (setf (buffer-string) "")
	      (lsp-isar-parse-output parsed-content)
	      (goto-char (point-min))
	      (ignore-errors
		(search-forward "Proof outline with cases:") ;; TODO this should go to lsp-isar-parse-output
		(setq lsp-isar-proof-cases-content (buffer-substring (point) (point-max))))))
	  (with-current-buffer lsp-isar-output-buffer
	    (read-only-mode t))))
    ('abort-rendering
     (message "updating goal interrupted (too slow)")
     nil)))

;; deactivate font-lock-mode because we to the fontification ourselves anyway.
(defun lsp-isar-initialize-output-buffer ()
  (setq lsp-isar-state-buffer (get-buffer-create "*lsp-isar-state*"))
  (setq lsp-isar-output-buffer (get-buffer-create "*lsp-isar-output*"))
  (save-excursion
    (with-current-buffer lsp-isar-state-buffer
      (read-only-mode t)
      (isar-goal-mode)
      (font-lock-mode nil))
    (with-current-buffer lsp-isar-output-buffer
      (read-only-mode t)
      (isar-goal-mode)
      (font-lock-mode nil))))

(defun lsp-isar-insert-cases ()
  "insert the last seen outline"
  (interactive)
  (insert lsp-isar-proof-cases-content))

(defun lsp-isar-update-state-and-output-buffer (content)
  "Launch the thread to update the state and the output panel"
  (if lsp-isar-proof-timer
      (cancel-timer lsp-isar-proof-timer))

  (if lsp-isar-time-before-printing-goal
      (setq lsp-isar-proof-timer
	    (run-at-time lsp-isar-time-before-printing-goal nil
			 (lambda (content)
				(progn
				  (setq lsp-isar--last-start (time-to-seconds))
				  (lsp-isar--update-state-and-output-buffer content)))
			 content))))


(modify-coding-system-alist 'file "*lsp-isar-output*" 'utf-8-auto)

(provide 'lsp-output)
