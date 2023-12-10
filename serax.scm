(define-module (serax)
  #:use-module (gnu)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (guix records)
  #:export (;; Serax Proxy Record
	    
	    serax-proxy
	    make-serax-proxy
	    serax-proxy?
	    serax-proxy-addresses

	    ;; Serax Engine Record 
	    
	    serax-engine
	    make-serax-engine
	    serax-engine?
	    serax-engine-name
	    serax-engine-engine
	    serax-engine-shortcut
	    serax-engine-base-url
	    serax-engine-categories
	    serax-engine-timeout
	    serax-engine-api-key
	    serax-engine-disabled
	    serax-engine-language
	    serax-engine-weight
	    serax-eninge-display-error-messages
	    serax-engine-proxies

	    ;; Serax Configuration Record
	    
	    serax-configuration
	    make-serax-configuration
	    serax-configuraiton?

	    ;; General
	    serax-configuration-package
	    serax-configuration-instance-name
	    serax-configuration-git-url
	    serax-configuration-issue-url
	    serax-configuration-docs-url
	    serax-configuration-public-instances
	    serax-configuration-contact-url
	    serax-configuration-wiki-url
	    serax-configuration-twitter-url

	    ;; Server
	    serax-configuration-port
	    serax-configuration-bind-address
	    serax-configuration-secret-key
	    serax-configuration-base-url
	    serax-configuration-image-proxy
	    serax-configuration-default-locale
	    serax-configuration-default-theme

	    ;; Outgoing
	    serax-configuration-http-headers
	    serax-configuration-request-timeout
	    serax-configuration-useragent-suffix
	    serax-configuration-pool-connections
	    serax-configuration-pool-maxsize
	    serax-configuration-proxies
	    serax-configuration-source-ips

	    ;; Functions

	    serax-configuration->string
	    serax-shepherd-service
	    serax-accounts

	    ;; Service Types
	    
	    serax-service-type
	    
	    ))



(define-record-type* <searx-proxy>
  searx-proxy make-searx-proxy
  searx-proxy?
  (addresses searx-proxy-addresses))

(define-record-type* <searx-engine>
  searx-engine make-searx-engine
  searx-engine?
  (name searx-engine-name)
  (engine searx-engine-engine)
  (shortcut searx-engine-shortcut)
  (base-url searx-engine-base-url
	    (default #f))
  (categories searx-engine-categories
	      (default #f))
  (timeout searx-engine-timeout
	   (default #f))
  (api-key searx-engine-api-key
	   (default #f))
  (disabled searx-engine-disabled
	    (default #f))
  (language searx-engine-language
	    (default #f))
  (weight searx-engine-weight
	  (default 1))
  (display-error-messages searx-engine-display-error-messages
			  (default #f))
  (proxies searx-engine-proxies
	  (default '())))

(define-record-type* <searx-configuration>
  searx-configuration make-searx-configuration
  searx-configuration?
  (searx searx-configuration-package
	 (default searx))

  ;; General
  (instance-name serax-configuration-instance-name
		 (default "searx"))
  (git-url searx-configuration-git-url
	   (default #f))
  (git-branch searx-configuration-git-branch
	      (default #f))
  (issue-url searx-configuration-issue-url
	     (default "https://github.com/searx/searx/issues"))
  (docs-url searx-configuration-docs-url
	    (default "https://searx.github.io/searx"))
  (public-instances searx-configuration-public-instances
		   (default '("https://searx.space")))
  (contact-url searx-configuration-contact-url
	       (default #f))
  (wiki-url searx-configuration-wiki-url
	    (default #f))
  (twitter-url searx-configuration-twitter-url
	       (default #f))

  ;; Server
  (port searx-configuration-port
	(default 888))
  (bind-address searx-configuration-bind-address
		(default "127.0.0.1"))
  (secret-key searx-configuration-secret-key)
  (base-url searx-configuration-base-url
	    (default #f))
  (image-proxy searx-configuration-image-proxy
	       (default #f))
  (default-locale searx-configuration-default-locale
    (default ""))
  (default-theme searx-configuration-default-theme
    (default "oscar"))

  ;; Outgoing
  (default-http-headers searx-configuration-default-http-headers
    (default (list "X-Content-Type-Options : nosniff"
		   "X-XSS-Protection : 1; mode=block"
		   "X-Download-Options :_noopen"
		   "X-Robot-Tag :_noindex, nofollow"
		   "Preferrer-Policy :_no-referrer")))
  (request-timeout searx-configuration-request-timeout
		   (default 2))
  (useragent-suffix searix-configuration-useragent-suffix
		    (default ""))
  (pool-connections searx-configuration-pool-connections
		    (default 100))
  (pool-maxsize searx-configuration-pool-maxsize
		(default 10))
  (proxies searx-configuration-proxies
	   (default '()))
  (source-ips searx-configuration-source-ips
	      (default '())))

(define (serax-configuration->string config)
  (string-join))

(define (searx-shepherd-service	config)
  (let ([conf (plain-file "settings.yml"
			  (serax-configuration->string config))])
    (shepherd-service
     (provision '(serax))
     (requirement '(user-processes networking))
     (start #~(make-forexec-constructor
	       (list #$(file-append (searx-configuraton-searx config)
				    "/bin/searx-run"))
	       #:enviroment-variables
	       (list (string-append "SERAX_SETTINGS_PATH="
				    #$conf))
	       #:user "searx"
	       #:group "searx"
	       #:pid-file "/var/run/searx.pid"))
     (stop #~(make-kill-destructor)))))

(define (searx-accounts config)
  (define nologin
    (file-append shadow "/sbin/nologin"))
  (list (user-group (name "searx") (system? #t))
	(user-account (system? #t)
		      (name "searx")
		      (group "searx")
		      (home-directory "/var/empty")
		      (create-home-directory? #f)
		      (shell nologin))))

(define searx-service-type
  (service-type (name 'searx)
		(extensions
		 (list (service-extension shepherd-root-service-type
					  searx-shepherd-service)
		       (service-extension account-service-type
					  searx-accounts)))
		(description
		 "Run @uref{https://searx.github.io/searx/},
a free internet metasearch engine.")))

  
