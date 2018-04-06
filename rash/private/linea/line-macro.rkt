#lang racket/base

;; struct properties and syntax classes for defining and detecting line macros

(provide
 #%linea-line
 #%linea-not-line
 #%linea-expressions-begin

 define-line-macro
 with-default-line-macro
 splicing-with-default-line-macro

 default-line-macro
 )

(require
 racket/stxparam
 racket/splicing
 (for-syntax
  "private/line-macro-detect.rkt"
  racket/base
  syntax/parse
  ))


(define-syntax (define-line-macro stx)
  (syntax-case stx ()
    [(_ name transformer)
     #'(define-syntax name (line-macro-struct transformer))]))

(define-syntax (#%linea-line stx)
  ;; detect line macros and apply them, or transform into pipeline
  (syntax-parse stx
    [(_ arg1:line-macro arg ...)
     (linea-line-macro-transform #'(arg1 arg ...))]
    [(rec arg ...)
     (let ([default-macro (syntax-parameter-value #'default-line-macro)])
       #`(rec #,default-macro arg ...))]))

(define-syntax #%linea-expressions-begin (make-rename-transformer #'begin))

;;; #%linea-not-line is just a pass-through -- it's what wraps normal Racket forms
;;; when they are completely escaped from the line syntax.
(define-syntax (#%linea-not-line stx)
  (syntax-parse stx [(_ e) #'e]))

(define-line-macro erroring-default-line-macro
  (λ (stx)
    (raise-syntax-error 'erroring-default-line-macro
                        "Currently the default line macro is just an error."
                        stx)))

(define-syntax-parameter default-line-macro #'erroring-default-line-macro)

(define-syntax (with-default-line-macro stx)
  (syntax-parse stx
    [(_ new-default:line-macro e ...+)
     #'(syntax-parameterize ([default-line-macro #'new-default])
         e ...)]))

(define-syntax (splicing-with-default-line-macro stx)
  (syntax-parse stx
    [(_ new-default:line-macro e ...+)
     #'(splicing-syntax-parameterize ([default-line-macro #'new-default])
         e ...)]))

(module+ test
  (require rackunit)
  (define-line-macro app (syntax-parser [(_ op e ...) #'(#%app op e ...)]))
  (define-line-macro rpn-app (syntax-parser [(_ e ... op) #'(#%app op e ...)]))

  (check-equal? (with-default-line-macro
                  app
                  (#%linea-expressions-begin
                   (#%linea-line + 4 5 6)))
                15)
  (check-equal? (with-default-line-macro
                  app
                  (#%linea-expressions-begin
                   (#%linea-line rpn-app 4 5 6 +)))
                15)
  (check-equal? (splicing-with-default-line-macro
                  app
                  (#%linea-expressions-begin
                   (#%linea-line + 4 5 6)))
                15)
  )