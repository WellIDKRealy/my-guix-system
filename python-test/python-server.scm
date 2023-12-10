(define-module (python-test python-server)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages python)
  #:use-module (gnu packages bash)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy))

(define-public python-server
  (package
    (name "python-server")
    (version "1.1")
    (source (local-file "/etc/system-config/python-test/python-server.tar"))
    (build-system copy-build-system)
    (arguments
     '(#:install-plan
       '(("python-server.py" "bin/"))))
    (inputs (list python-3))
    (propagated-inputs (list bash))
    (home-page "")
    (synopsis "")
    (description "")
    (license license:gpl3+)))

(define-public (python-server-shepherd-service pkg)
  (list (shepherd-service
	 (provision '(python-server))
	 (start #~(make-forkexec-constructor
		   (list #$(file-append pkg "/bin/python-server.py"))))
	 (stop #~(make-kill-destructor)))))

(define-public python-server-service-type
  (service-type
   (name 'python-server)
   (description "")
   (extensions
    (list (service-extension shepherd-root-service-type
			     python-server-shepherd-service)))
   (default-value python-server)))


python-server
