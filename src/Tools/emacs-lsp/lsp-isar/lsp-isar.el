;;; -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Mathias Fleury

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


(require 'lsp-mode)
(require 'lsp-output)
(require 'lsp-caret)
(require 'lsp-output)
(require 'lsp-progress)
(require 'lsp-decorations)
(require 'lsp-indentation)

(defcustom lsp-isar-init-hook nil
   "List of functions to be called after Isabelle has been started."
   :type 'hook)

(defvar lsp-isar--already-initialised nil
  "boolean to indicate if we have already initialised progress updates,
the output buffer, and the initial hooks.")


;; lsp-after-initialize-hook might look like the right macro. However, the
;; workspace (lsp--cur-workspace) is not opened yet.
(add-hook 'lsp-after-open-hook
	  (lambda()
	    (if (equal major-mode 'isar-mode)
		(progn
		  (lsp-isar-activate-caret-update)
		  (unless lsp-isar--already-initialised
		    (progn
		      (lsp-isar-initialize-output-buffer)
		      (lsp-isar-activate-progress-update)
		      (run-hooks 'lsp-isar-init-hook)
		      (setq lsp-isar--already-initialised t)))))))

(defvar lsp-isar--already-split nil
  "boolean to indicate if we have already split the window")

;; unconditionnaly split the window
(defun lsp-isar-open-output-and-progress-right ()
   "opens the *isar-output* and *isar-progress* buffers on the right"
   (interactive)
   (split-window-right)
   (other-window 1)
   (switch-to-buffer "*isar-output*")
   (split-window-below)
   (other-window 1)
   (switch-to-buffer "*isar-progress*")
   (other-window -2))

;; split the window 2 seconds later (the timeout is necessary to give
;; enough time to spacemacs to jump to the theory file) It can be used
;; for example by ``(add-hook 'lsp-isar-init-hook
;; 'lsp-isar-open-output-and-progress-right-spacemacs)''
(defun lsp-isar-open-output-and-progress-right-spacemacs ()
  (run-at-time 2 nil (lambda () (lsp-isar-open-output-and-progress-right))))

(defun lsp-isar--initialize-client (client)
  (lsp-client-on-notification client "PIDE/decoration" 'isar-update-and-reprint)
  (lsp-client-on-notification client "PIDE/dynamic_output"
			      (lambda (w _p) (isar-update-output-buffer (gethash "content" _p))))
  (lsp-client-on-notification client "PIDE/progress"
			      (lambda (w _p)
				(isar-update-progress-buffer (gethash "nodes_status" _p)))))

(defcustom lsp-isar-path-to-isabelle "/home/zmaths/Documents/isabelle/isabelle2018-vsce"
  "default path to Isabelle (e.g., /path/to/isabelle/folder)")

(defcustom lsp-isabelle-options (list "-m" "do_notation")
  "Isabelle options (e.g, AFP)")

(defcustom lsp-vscode-options
  (list
   "-o" "vscode_unicode_symbols"
   "-o" "vscode_pide_extensions"
   "-o" "vscode_caret_perspective=10")
  "Isabelle's LSP server options")

(defun lsp-full-isabelle-path ()
  "full isabelle command"
  (append
   (list (concat lsp-isar-path-to-isabelle "/bin/isabelle")
	 "vscode_server")
   lsp-vscode-options
   lsp-isabelle-options
   ))

(defvar lsp-isar-already-defined-client nil)

(defun lsp-isar-define-client ()
  "defines the lsp-isar-client"
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection ((lambda () (lsp-full-isabelle-path))))
    :major-modes '(isar-mode)
    :server-id 'lsp-isar
    :priority 1
    ;;  :use-native-json t
    :notification-handlers
    (lsp-ht
     ("PIDE/decoration" 'isar-update-and-reprint)
     ("PIDE/dynamic_output" (lambda (w _p) (isar-update-output-buffer (gethash "content" _p))))
     ("PIDE/progress" (lambda (w _p) (isar-update-progress-buffer (gethash "nodes_status" _p)))))
    )))

(defun lsp-isar-define-client-and-start ()
  (unless lsp-isar-already-defined-client
      (progn
	(lsp-isar-define-client)
	(setq lsp-isar-already-defined-client t)))
  (lsp))

;; declare the lsp mode
(setq lsp-language-id-configuration
      (cons '(isar-mode . "isabelle") lsp-language-id-configuration))

(defcustom lsp-isar-remote-path-to-isabelle "/home/zmaths/Documents/isabelle/isabelle2018-vsce" "default path to Isabelle (e.g., /path/to/isabelle/folder)")

(defcustom lsp-remote-isabelle-options (list "-m" "do_notation") "Isabelle options (e.g, AFP)")

(defvar lsp-full-remote-isabelle-path
  (append
   (list (concat lsp-isar-remote-path-to-isabelle "/bin/isabelle")
	 "vscode_server")
   lsp-vscode-options
   lsp-remote-isabelle-options)
  "full remote isabelle command")

;; (lsp-register-client
;;  (make-lsp-client
;;   :new-connection (lsp-tramp-connection lsp-full-remote-isabelle-path)
;;   :major-modes '(isar-mode)
;;   :server-id 'lsp-isar
;;   :remote? t
;;   :notification-handlers
;;   (lsp-ht
;;    ("PIDE/decoration" 'isar-update-and-reprint)
;;    ("PIDE/dynamic_output" (lambda (w _p) (isar-update-output-buffer (gethash "content" _p))))
;;    ("PIDE/progress" (lambda (w _p) (isar-update-progress-buffer (gethash "nodes_status" _p)))))
;;   ;:library-folders-fn (lambda (_workspace) lsp-clients-isabelle-library-directories)
;;   ))


;; although the communication to the LSP server is done using utf-16,
;; we can only use utf-18
(modify-coding-system-alist 'file "\\.thy\\'" 'utf-8-auto)


(defvar lsp-isar-expiremental nil
  "experimental settings")

(if lsp-isar-expiremental
    (add-hook 'isar-mode-hook
	      '(lambda () (set (make-local-variable 'indent-line-function) 'isar-indent-line))))

(provide 'lsp-isar)
