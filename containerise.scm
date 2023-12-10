(define-module (containerise)
  #:use-module (gnu)
  #:use-module (gnu services shepherd)
  #:use-module (gnu build linux-container)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-1)
  #:export (containerise-service-type
	    containerise-service))

(define-syntax define-macro*
  (syntax-rules ()
    [(define-macros* (name args ...)
       body)
     (define-macro (name . rest)
       (apply (lambda* (args ...) body) rest))]))

(define-syntax gnu:service
  (syntax-rules ()
    [(gnu:service args ...)
     (service args ...)]))

(define* (containerise-service service
			       #:key
			       (mounts %container-file-systems)
			       (namespaces %namespaces)
			       (host-uids 1)
			       (guest-uid 0)
			       (guest-gid 0)
			       (relayed-signals (list SIGINT SIGTERM))
			       (child-is-pid1? #t)
			       (process-spawned-hook #~(const #t)))
  (gnu:service (containerise-service-type (service-kind service)
     					  #:mounts mounts
					  #:namespaces namespaces
					  #:host-uids host-uids
					  #:guest-uid guest-uid
					  #:guest-gid guest-gid
					  #:relayed-signals relayed-signals
					  #:child-is-pid1? child-is-pid1?
					  #:process-spawned-hook process-spawned-hook)
	       (service-value service)))

(define-syntax gnu:service-type
  (syntax-rules ()
    [(gnu:service-type args ...)
     (service-type args ...)]))

(define* (containerise-service-type service-type
				    #:key
				    (mounts %container-file-systems)
				    (namespaces %namespaces)
				    (host-uids 1)
				    (guest-uid 0)
				    (guest-gid 0)
				    (relayed-signals (list SIGINT SIGTERM))
				    (child-is-pid1? #t)
				    (process-spawned-hook #~(const #t)))
  (gnu:service-type
   (inherit service-type)
   (extensions
    (map (lambda (ext)
	   (let ([target (service-extension-target ext)]
		 [compute (service-extension-compute ext)])
	     (if (eq? target
		      shepherd-root-service-type)
		 (service-extension
		  target
		  (lambda args
		    (map (lambda (service)
			   (shepherd-service
			    (inherit service)
			    (start (with-imported-modules
				    '((gnu build linux-container))
				    #~(begin
					(use-modules (gnu build linux-container))
					(let ([proc #$(shepherd-service-start service)])
					  (lambda args
					    (call-with-container
					     #$(if (gexp? mounts)
						    mounts
						    (gexp (ungexp mounts)))
					     (lambda () (apply proc args))
					     #:namespaces #$namespaces
					     #:host-uids #$host-uids
					     #:guest-uid #$guest-uid
					     #:guest-gid #$guest-gid
					     #:relayed-signals #$relayed-signals
					     #:child-is-pid? #$child-is-pid1?
					     #:process-spawned-hook #$process-spawned-hook))))
				    ))))
			 (apply compute args))))
		 ext)))
	 (service-type-extensions service-type)))))
