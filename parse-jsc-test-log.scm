#!/usr/bin/guile-2.0 \
-e main -s
!#

(use-modules (ice-9 rdelim))
(use-modules (ice-9 match))
(use-modules (ice-9 vlist))
(use-modules (srfi srfi-1))

(define (tokenize)
  (let ((line (read-line)))
  (if (eof-object? line)
    line 
    (string-split (string-trim-right line) #\:))))

(define (split-on-last s char)
  (let ((dot-index (string-rindex s char)))
    (list (string-drop s (1+ dot-index)) 
          (string-take s dot-index))))

; we get something like: "path/test-name.js.test-kind". We return a list
; '(test-kind "path/test.name")
(define (parse-test-run test-run)
  (match (split-on-last test-run #\.)
         ((test-kind test-path) (list (string->symbol test-kind) test-path))))

(define (fail-parse-fold proc seed)
  (let lp ((tokens (tokenize))
           (seed seed))
    (match
      tokens
      ((? eof-object? eof) seed)
      (("FAIL" test-run)
       (lp (tokenize)
           (proc (cons 'fail (parse-test-run (string-trim test-run))) seed)))
      ((test-run " Bus error")
       (lp (tokenize) (proc (cons 'bus-error (parse-test-run test-run)) seed)))
      ((test-run " Timed out after 1200.000000 seconds!")
       (lp (tokenize) (proc (cons 'time-out (parse-test-run test-run)) seed)))
      ((test-run " Timed out after 1200.000000 sec seconds!")
       (lp (tokenize) (proc (cons 'time-out (parse-test-run test-run)) seed)))
      ((test-run " Timed out after 169.000000 sec seconds!")
       (lp (tokenize) (proc (cons 'time-out (parse-test-run test-run)) seed)))
     (_ (lp (tokenize) seed)))))

;(define (crash-parse-fold proc seed)
;  (let lp ((tokens (tokenize))
;           (seed seed))
;    (match
;      tokens
;      ((? eof-object? eof) seed)
;      (("FAIL" test-run)
;       (lp (tokenize)
;           (proc (cons 'fail (parse-test-run (string-trim test-run))) seed)))
;      ((test-run " Bus error")
;       (let ((test-name (parse-test-run test-run)))
;       (lp (tokenize)
;           (proc (cons 'fail test-name
;                       (proc (cons 'bus-error test-name) seed))))))
;      ((test-run " Timed out after 1200.000000 seconds!")
;       (lp (tokenize) (proc (cons 'time-out (parse-test-run test-run)) seed)))
;      ((test-run " Timed out after 1200.000000 sec seconds!")
;       (lp (tokenize) (proc (cons 'time-out (parse-test-run test-run)) seed)))
;     (_ (lp (tokenize) seed)))))



(define (add-fail fail fails)
  (match
    fail
    ((fail-type kind path) 
     (vhash-cons path (cons fail-type kind) fails))))

(define (vhash-keys vhash)
  (vhash-fold 
    (λ (key _ keys) (lset-adjoin equal? keys key))
    '()
    vhash))

; for each key in vhash, apply (proc key vals previous) with vals the list of
; values stored under key in vhash, and previous the result of the latest proc
; application. For the first proc call, init is used for previous.
(define (vhash-key-fold proc init vhash)
  (let ((keys (vhash-keys vhash)))
    (fold
      (λ (key seed) 
         (let ((vals (vhash-fold* cons '() key vhash)))
           (proc key vals seed)))
      init
      keys)))

; (define* (vhash-key-fold proc init vhash #:optional (pred (λ _ #t)))
;          (vhash-key-fold-impl
;            (λ (key vals previous)
;               (if (pred key vals)
;                 (proc key vals previous)
;                 previous))
;            init vhash))

; Make all the values lists. If a key appears more than once, we make it
; appear only once and its values appear as one value which is a list
; containing all the values.
(define (merge-alist alist)
  (vhash-key-fold
    acons
    '()
    (alist->vhash alist)))

; For each failing test in the log passed in the current input port, calls
; (proc test-path vals) where vals is an alist failure-type → test-run-kind-list
(define (for-each-crash proc)
   (let ((all-fails (fail-parse-fold add-fail vlist-null)))
     (vhash-key-fold
       (λ (test-path vals _)
          (proc test-path (merge-alist vals)))
       #f
       all-fails)))

(define (has-bus-error? vals)
  (let ((failure-types (map car vals)))
    (and (memq 'bus-error failure-types)
         (not (memq 'time-out failure-types)))))

(define (has-default-bus-error? vals)
  (let ((bus-error-test-kinds (assq-ref vals 'bus-error))) 
    (and bus-error-test-kinds
         (not (assq 'time-out vals))
         (memq 'default bus-error-test-kinds))))

; Takes log in input port and prints a list of crashes that are not due to
; time outs
(define (print-true-default-crashes)
  (for-each-crash
    (λ (test-path vals)
       (when (has-default-bus-error? vals)
         (format #t "~a~%" test-path)))))


(define (print-timeouts)
  (for-each-crash
    (λ (test-path vals)
       (when (assq 'time-out vals)
         (format #t "~a~%" test-path)))))

(define (print-non-default-crashes)
  (for-each-crash
    (λ (test-path vals)
       (when (and (has-bus-error? vals)
                  (not (has-default-bus-error? vals)))
         (format #t "~a ~s~%" test-path (assq-ref vals 'bus-error))))))

(define (print-simple-fails)
  (for-each-crash
    (λ (test-path vals)
       (unless (or (assq 'time-out vals)
                   (assq 'bus-error vals))
         (format #t "~a ~s~%" test-path (assq-ref vals 'fail))))))

(define (main args)
  (match
    args
    ((_ "print-all" log-file)
     (with-input-from-file
       log-file
       (λ () (fail-parse-fold (λ (fail seed) (write-line fail)) #f))))
    ((_ "print-true-default-crashes" log-file)
     (with-input-from-file log-file print-true-default-crashes))
    ((_ "print-timeouts" log-file)
     (with-input-from-file log-file print-timeouts))
    ((_ "print-non-default-crashes" log-file)
     (with-input-from-file log-file print-non-default-crashes))
    ((_ "print-simple-fails" log-file)
     (with-input-from-file log-file print-simple-fails))
    ((cl . _) (format (current-error-port) "Wrong syntax. Usage: ~A command log-file~%" cl)
              (format (current-error-port) "Available Commands:~%")
              (format (current-error-port) "  print-all log-file~%")
              (format (current-error-port) "  print-true-default-crashes log-file~%")
              (format (current-error-port) "  print-timeouts log-file~%")
              (format (current-error-port) "  print-non-default-crashes log-file~%")
              (format (current-error-port) "  print-simple-fails log-file~%"))))
