(define-module (guix scripts s6)
  #:use-module (gnu packages admin)
  #:use-module (gnu services)
 ;#:use-module (gnu s6)
 ;#:use-module (gnu s6-services)
  #:use-module (guix channels)
  #:autoload   (guix scripts pull) (channel-commit-hyperlink)
  #:use-module (guix derivations)
  #:use-module (guix ui)
  #:use-module (guix grafts)
  #:use-module (guix packages)
  #:use-module (guix profiles)
  #:use-module (guix store)
  #:use-module (guix utils)
  #:use-module (guix scripts)
  #:use-module (guix scripts package)
  #:use-module (guix scripts build)
  #:use-module (guix scripts system search)
  #:use-module ((guix status) #:select (with-status-verbosity))
  #:use-module (guix gexp)
  #:use-module (guix monads)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-35)
  #:use-module (srfi srfi-37)
  #:use-module (ice-9 match)
  #:use-module (ice-9 pretty-print)
  #:export (guix-s6))

;(define %user-module
;  ;; Module in which the machine description file is loaded.
;  (make-user-module '((gnu s6))))

(define %guix-s6
  (string-append %profile-directory "/guix-s6"))

(define (show-help)
  (display (G_ "Usage: guix s6 [OPTION ...] ACTION [ARG ...] [FILE]
Build the s6 environment declared in FILE according to ACTION.
Some ACTIONS support additional ARGS.\n"))
    (newline)
  (display (G_ "The valid values for ACTION are:\n"))
  (newline)
  (display (G_ "\
   search             search for existing service types\n"))
  (display (G_ "\
   reconfigure        switch to a new s6 environment configuration\n"))
  (display (G_ "\
   roll-back          switch to the previous s6 environment configuration\n"))
  (display (G_ "\
   describe           describe the current s6 environment\n"))
  (display (G_ "\
   list-generations   list the s6 environment generations\n"))
  (display (G_ "\
   switch-generation  switch to an existing s6 environment configuration\n"))
  (display (G_ "\
   delete-generations delete old s6 environment generations\n"))
  (display (G_ "\
   build              build the s6 environment without installing anything\n"))

  ;; (show-build-options-help)
  (newline)
  (show-bug-report-information))

(define (verbosity-level opts)
  "Return the verbosity level based on OPTS, the alist of parsed options."
  (or (assoc-ref opts 'verbosity)
      (if (eq? (assoc-ref opts 'action) 'build)
          2 1)))

(define %options
  ;; Specification of the command-line options.
  (list (option '(#\h "help") #f #f
                (lambda args
                  (show-help)
                  (exit 0)))
        (option '(#\V "version") #f #f
                (lambda args
                  (show-version-and-exit "guix show")))
        (option '(#\v "verbosity") #t #f
                (lambda (opt name arg result)
                  (let ((level (string->number* arg)))
                    (alist-cons 'verbosity level
                                (alist-delete 'verbosity result)))))
        (find (lambda (option)
                (member "load-path" (option-names option)))
              %standard-build-options)))

(define %default-options
  `((substitutes? . #t)
    (graft? . #t)
    (debug . 0)))


(define* (perform-action action he
			 #:key
                         dry-run?
			 derivations-only?
                         use-substitutes?)
  "Perform ACTION for s6 environment. "

  (define println
    (cut format #t "~a~%" <>))

  (mlet* %store-monad
      ((he-drv   (s6-environment-derivation he))
       (drvs     (mapm/accumulate-builds lower-object (list he-drv)))
       (%        (if derivations-only?
                     (return
		      (for-each (compose println derivation-file-name) drvs))
                     (built-derivations drvs)))

       (he-path -> (derivation->output-path he-drv)))
    (if (or dry-run? derivations-only?)
	(return #f)
        (begin
          (for-each (compose println derivation->output-path) drvs)

          (case action
	    ((reconfigure)
	     (let* ((number (generation-number %guix-s6))
                    (generation (generation-file-name
				 %guix-s6 (+ 1 number)))

		    (user-s6-environment-symlink-path
		     (s6-environment-symlink-path he)))
	       (switch-symlinks generation he-path)
	       (switch-symlinks %guix-s6 generation)
	       (switch-symlinks user-s6-environment-symlink-path
				%guix-s6)

	       (primitive-load (string-append he-path "/activate"))
	       (return he-path)))
            (else
             (newline)
	     (return he-path)))))))

(define (process-action action args opts)
  "Process ACTION, a sub-command, with the arguments are listed in ARGS.
ACTION must be one of the sub-commands that takes a s6 environment
declaration as an argument (a file name.)  OPTS is the raw alist of options
resulting from command-line parsing."
  (define (ensure-s6-environment file-or-exp obj)
    (unless (s6-environment? obj)
      (leave (G_ "'~a' does not return a s6 environment ~%")
             file-or-exp))
    obj)

  (let* ((file   (match args
                   (() #f)
                   ((x . _) x)))
         (expr   (assoc-ref opts 'expression))
         (system (assoc-ref opts 'system))

	 (transform   (lambda (obj)
                        (s6-environment-with-provenance obj file)))

         (s6-environment
	  (transform
           (ensure-s6-environment
            (or file expr)
            (cond
             ((and expr file)
              (leave
               (G_ "both file and expression cannot be specified~%")))
             (expr
              (read/eval expr))
             (file
              (load* file %user-module
                     #:on-error (assoc-ref opts 'on-error)))
             (else
              (leave (G_ "no configuration specified~%")))))))

         (dry?        (assoc-ref opts 'dry-run?)))

    (with-store store
      (set-build-options-from-command-line store opts)
      (with-build-handler (build-notifier #:use-substitutes?
                                          (assoc-ref opts 'substitutes?)
                                          #:verbosity
                                          (verbosity-level opts)
                                          #:dry-run?
                                          (assoc-ref opts 'dry-run?))

        (run-with-store store
          (mbegin %store-monad
	    (set-guile-for-build (default-guile))

	    (case action
              (else
               ;; (unless (eq? action 'build)
               ;;   (warn-about-old-distro #:suggested-command
               ;;                          "guix s6 reconfigure"))
               (perform-action action s6-environment
                               #:dry-run? dry?
                               #:derivations-only? (assoc-ref opts 'derivations-only?)
                               #:use-substitutes? (assoc-ref opts 'substitutes?))
	       ))))))
    (warn-about-disk-space)))


(define (process-command command args opts)
  "Process COMMAND, one of the 'guix s6' sub-commands.  ARGS is its
argument list and OPTS is the option alist."
  (define-syntax-rule (with-store* store exp ...)
    (with-store store
		(set-build-options-from-command-line store opts)
		exp ...))
  (case command
    ;; The following commands do not need to use the store, and they do not need
    ;; an operating s6 environment file.
    ((search)
     (apply search args))
    ((describe)
     (match (generation-number %guix-s6)
       (0
        (error (G_ "no s6 environment generation, nothing to describe~%")))
       (generation
        (display-s6-environment-generation generation))))
    ((list-generations)
     (let ((pattern (match args
                      (() #f)
                      ((pattern) pattern)
                      (x (leave (G_ "wrong number of arguments~%"))))))
       (list-generations pattern)))
    ((switch-generation)
     (let ((pattern (match args
                      ((pattern) pattern)
                      (x (leave (G_ "wrong number of arguments~%"))))))
       (with-store* store
		    (switch-to-s6-environment-generation store pattern))))
    ((roll-back)
     (let ((pattern (match args
                      (() "")
                      (x (leave (G_ "wrong number of arguments~%"))))))
       (with-store* store
		    (roll-back-s6-environment store))))
    ((delete-generations)
     (let ((pattern (match args
                      (() #f)
                      ((pattern) pattern)
                      (x (leave (G_ "wrong number of arguments~%"))))))
       (with-store*
	store
	(delete-matching-generations store %guix-s6 pattern))))
    (else (process-action command args opts))))

(define-command (guix-s6 . args)
  (synopsis "build and deploy s6 environments")

  (define (parse-sub-command arg result)
    ;; Parse sub-command ARG and augment RESULT accordingly.
    (if (assoc-ref result 'action)
        (alist-cons 'argument arg result)
        (let ((action (string->symbol arg)))
          (case action
            ((build
	      reconfigure
	      extension-graph s6-graph
	      list-generations describe
	      delete-generations roll-back
	      switch-generation search)
             (alist-cons 'action action result))
            (else (leave (G_ "~a: unknown action~%") action))))))

  (define (match-pair car)
    ;; Return a procedure that matches a pair with CAR.
    (match-lambda
      ((head . tail)
       (and (eq? car head) tail))
      (_ #f)))

  (define (option-arguments opts)
    ;; Extract the plain arguments from OPTS.
    (let* ((args   (reverse (filter-map (match-pair 'argument) opts)))
           (count  (length args))
           (action (assoc-ref opts 'action))
           (expr   (assoc-ref opts 'expression)))
      (define (fail)
        (leave (G_ "wrong number of arguments for action '~a'~%")
               action))

      (unless action
        (format (current-error-port)
                (G_ "guix s6: missing command name~%"))
        (format (current-error-port)
                (G_ "Try 'guix s6 --help' for more information.~%"))
        (exit 1))

      (case action
        ((build reconfigure)
         (unless (or (= count 1)
                     (and expr (= count 0)))
           (fail)))
        ((init)
         (unless (= count 2)
           (fail))))
      args))

  (with-error-handling
    (let* ((opts     (parse-command-line args %options
					 (list %default-options)
                                         #:argument-handler
                                         parse-sub-command))
           (args     (option-arguments opts))
           (command  (assoc-ref opts 'action)))
      ;; (pretty-print opts)
      ;; (pretty-print args)
      ;; (pretty-print command)
      ;; (pretty-print (assoc-ref opts 'graft?))
      (parameterize ((%graft? (assoc-ref opts 'graft?)))
        (with-status-verbosity (verbosity-level opts)
          (process-command command args opts))))))


;;;
;;; Searching.
;;;

(define service-type-name*
  (compose symbol->string service-type-name))

(define (service-type-description-string type)
  "Return the rendered and localised description of TYPE, a service type."
  (and=> (service-type-description type)
         (compose texi->plain-text P_)))

(define %service-type-metrics
  ;; Metrics used to estimate the relevance of a search result.
  `((,service-type-name* . 3)
    (,service-type-description-string . 2)
    (,(lambda (type)
        (match (and=> (service-type-location type) location-file)
          ((? string? file)
           (basename file ".scm"))
          (#f
           "")))
     . 1)))

(define (find-service-types regexps)
  "Return a list of service type/score pairs: service types whose name or
description matches REGEXPS sorted by relevance, and their score."
  (let ((matches (fold-s6-service-types
                  (lambda (type result)
                    (match (relevance type regexps
                                      %service-type-metrics)
                      ((? zero?)
                       result)
                      (score
                       (cons (cons type score) result))))
                  '())))
    (sort matches
          (lambda (m1 m2)
            (match m1
              ((type1 . score1)
               (match m2
                 ((type2 . score2)
                  (if (= score1 score2)
                      (string>? (service-type-name* type1)
                                (service-type-name* type2))
                      (> score1 score2))))))))))

(define (search . args)
  (with-error-handling
    (let* ((regexps (map (cut make-regexp* <> regexp/icase) args))
           (matches (find-service-types regexps)))
      (leave-on-EPIPE
       (display-search-results matches (current-output-port)
                               #:print service-type->recutils
                               #:command "guix s6 search")))))


;;;
;;; Generations.
;;;

(define* (display-s6-environment-generation
	  number
          #:optional (profile %guix-s6))
  "Display a summary of s6-environment generation NUMBER in a
human-readable format."
  (define (display-channel channel)
    (format #t     "    ~a:~%" (channel-name channel))
    (format #t (G_ "      repository URL: ~a~%") (channel-url channel))
    (when (channel-branch channel)
      (format #t (G_ "      branch: ~a~%") (channel-branch channel)))
    (format #t (G_ "      commit: ~a~%")
            (if (supports-hyperlinks?)
                (channel-commit-hyperlink channel)
                (channel-commit channel))))

  (unless (zero? number)
    (let* ((generation  (generation-file-name profile number)))
      (define-values (channels config-file)
	;; The function will work for s6 environments too, we just
	;; need to keep provenance file.
        (system-provenance generation))

      (display-generation profile number)
      (format #t (G_ "  file name: ~a~%") generation)
      (format #t (G_ "  canonical file name: ~a~%") (readlink* generation))
      ;; TRANSLATORS: Please preserve the two-space indentation.

      (unless (null? channels)
        ;; TRANSLATORS: Here "channel" is the same terminology as used in
        ;; "guix describe" and "guix pull --channels".
        (format #t (G_ "  channels:~%"))
        (for-each display-channel channels))
      (when config-file
        (format #t (G_ "  configuration file: ~a~%")
                (if (supports-hyperlinks?)
                    (file-hyperlink config-file)
                    config-file))))))

(define* (list-generations pattern #:optional (profile %guix-s6))
  "Display in a human-readable format all the s6 environment
generations matching PATTERN, a string.  When PATTERN is #f, display
all the s6 environment generations."
  (cond ((not (file-exists? profile))             ; XXX: race condition
         (raise (condition (&profile-not-found-error
                            (profile profile)))))
        ((not pattern)
         (for-each display-s6-environment-generation (profile-generations profile)))
        ((matching-generations pattern profile)
         =>
         (lambda (numbers)
           (if (null-list? numbers)
               (exit 1)
               (leave-on-EPIPE
                (for-each display-s6-environment-generation numbers)))))))


;;;
;;; Switch generations.
;;;

;; TODO: Make it public in (guix scripts system)
(define-syntax-rule (unless-file-not-found exp)
  (catch 'system-error
    (lambda ()
      exp)
    (lambda args
      (if (= ENOENT (system-error-errno args))
          #f
          (apply throw args)))))

(define (switch-to-s6-environment-generation store spec)
  "Switch the s6-environment profile to the generation specified by
SPEC.  STORE is an open connection to the store."
  (let* ((number (relative-generation-spec->number %guix-s6 spec))
         (generation (generation-file-name %guix-s6 number))
         (activate (string-append generation "/activate")))
    (if number
        (begin
          (switch-to-generation* %guix-s6 number)
          (unless-file-not-found (primitive-load activate)))
        (leave (G_ "cannot switch to s6 environment generation '~a'~%") spec))))


;;;
;;; Roll-back.
;;;
(define (roll-back-s6-environment store)
  "Roll back the s6-environment profile to its previous generation.
STORE is an open connection to the store."
  (switch-to-s6-environment-generation store "-1"))

