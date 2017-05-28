(require 'rjsx-mode)
(require 'flow-mode)

(defgroup flow-js2-minor-mode nil
  "Support for flow annotations in JSX files."
  :group 'js2-mode)

;;;###autoload
(define-minor-mode flow-js2-minor-mode
  "Minor mode for editing JS files with flow type annotations."
  :lighter ":FLOW"
  :group 'flow-js2-minor-mode
  (dolist (kw '("boolean" "number" "string" "null" "void" "any" "mixed"))
    (add-to-list 'js2-additional-externs kw)))

(defun activate-flow-js2-minor-mode ()
  (when (and (flow-tag-present-p)
             ;; (flow-configured-p)
             )
    (flow-js2-minor-mode +1)))


(defvar flow-js2-parsing-typespec-p nil)
(defun flow-js2-create-name-node (orig-fun &rest args)
  (let ((name (apply orig-fun args)))
    (if (and flow-js2-minor-mode
             (not flow-js2-parsing-typespec-p))
        (apply 'flow-js2-do-create-name-node name args)
      name)))

(advice-add 'js2-create-name-node :around #'flow-js2-create-name-node)

(add-hook 'js2-mode-hook 'activate-flow-js2-minor-mode)

(defun flow-js2-do-create-name-node (name &optional check-activation-p token string)
  (let ((next (js2-peek-token)))
    (when (js2-match-token js2-COLON)
      (let* ((pos (js2-node-pos name))
             (tt (js2-current-token-type))
             (left name)
             (type-spec (js2-parse-flow-type-spec))
             (len (- (js2-node-end type-spec) pos)))
        (setq name (make-js2-flow-type-node :pos pos :len len :name name :typespec type-spec))
        (js2-node-add-children name left type-spec)))
    name))


;;; Node types

(cl-defstruct (js2-flow-type-node
               (:include js2-node)
               (:constructor nil)
               (:constructor make-js2-flow-type-node (&key (pos (js2-current-token-beg))
                                                           (len (- js2-ts-cursor
                                                                   (js2-current-token-beg)))
                                                           name
                                                           typespec)))
  "Represent a name with a flow type annotation."
  name
  typespec)

(put 'cl-struct-js2-flow-type-node 'js2-visitor 'js2-visit-none)
(put 'cl-struct-js2-flow-type-node 'js2-printer 'js2-print-flow-type-node)

(defun js2-print-flow-type-node (n i)
  (let* ((tt (js2-node-type n)))
    (js2-print-ast (js2-flow-type-node-name n) 0)
    (insert ": ")
    (js2-print-ast (js2-flow-type-node-typespec n) 0)))

(defun js2-parse-flow-type-spec ()
  (let ((flow-js2-parsing-typespec-p t)
        (tt (js2-get-token))
        (pos (js2-current-token-beg))
        pn)
    (when (= tt js2-NAME)
      (js2-parse-name tt))))

;;; Some helpers for symbol definition:

(defun flow-js2-define-symbol (orig-fun decl-type name &optional node ignore-not-in-block)
  (if (and (not (null node))
           (js2-flow-type-node-p node))
      (funcall orig-fun decl-type (js2-name-node-name (js2-flow-type-node-name node))
               (js2-name-node-name node)
               ignore-not-in-block)
    (funcall orig-fun decl-type name node ignore-not-in-block)))

(advice-add 'js2-define-symbol :around #'flow-js2-define-symbol)
