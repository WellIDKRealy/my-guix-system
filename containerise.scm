(define-module (containerise)
  #:use-module (gnu)
  #:use-module (gnu services shepherd)
  #:use-module (gnu build linux-container)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-1)
  #:export (containerise-service-type
	    containerise-service))

(define* (containerise-service service
			       #:key
			       (mounts %container-file-systems)
			       (namespaces %namespaces)
			       (host-uids 1)
			       (guest-uid 0)
			       (guest-gid 0)
			       (relayed-signals (list SIGINT SIGTERM))
			       (child-is-pid1? #t)
			       (process-spawned-hook (const #t)))
  (service (containerise-service-type (service-kind service)
				      mounts
				      #:namespaces namespaces
				      #:host-uids host-uids
				      #:guest-uid guest-uid
				      #:guest-gid guest-git
				      #:relayed-signals relayed-signals
				      #:child-is-pid? child-is-pid1?
				      #:process-spawned-hook process-spawned-hook)
	   (service-value service)))

(define* (containerise-service-type service-type
				    #:key
				    (mounts %container-file-systems)
				    (namespaces %namespaces)
				    (host-uids 1)
				    (guest-uid 0)
				    (guest-gid 0)
				    (relayed-signals (list SIGINT SIGTERM))
				    (child-is-pid1? #t)
				    (process-spawned-hook (const #t)))
  (service-type
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
			    (start #~(begin
				       (use-modules (gnu build linux-container))
				       (call-with-container #$mounts
					 (lambda () #$(shepherd-service-start service))
					 #:namespaces namespaces
					 #:host-uids host-uids
					 #:guest-uid guest-uid
					 #:guest-gid guest-git
					 #:relayed-signals relayed-signals
					 #:child-is-pid? child-is-pid1?
					 #:process-spawned-hook process-spawned-hook)
				       ))))
			 (apply args compute))))
		 ext)))
	 (service-type-extensions service-type)))))
