(use-modules (gnu)
	     (nongnu packages linux)
	     (nongnu system linux-initrd)
	     ;; Searx
	     (gnu services shepherd)
	     (gnu system shadow)
	     (guix records))

(use-package-modules wm search)
(use-service-modules cups desktop networking ssh xorg virtualization web
		     linux pm databases)

;; Custom services

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
  (searx searx-configuration-searx
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
  ;; server
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
  ;; outgoing
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

;; Operating sytem definition

(operating-system
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (cons* iwlwifi-firmware %base-firmware))
 
 (locale "en_US.utf8")
 (timezone "Europe/Warsaw")
 (keyboard-layout (keyboard-layout "us" #:options '("ctrl:swapcaps")))
 (host-name "x220")

 ;; The list of user accounts ('root' is implicit).
 (users (cons* (user-account
                (name "maciej")
                (comment "Maciej Kalandyk")
                (group "users")
                (home-directory "/home/maciej")
                (supplementary-groups '("wheel" "netdev" "audio" "video" "libvirt")))
               %base-user-accounts))

 ;; Packages installed system-wide.  Users can also install packages
 ;; under their own account: use 'guix search KEYWORD' to search
 ;; for packages and 'guix install PACKAGE' to install a package.
 (packages (append (list
		    sway
		    (specification->package "nss-certs"))
                   %base-packages))

 ;; Below is the list of system services.  To search for available
 ;; services, run 'guix system search KEYWORD' in a terminal.
 (services
  (append (list (service gnome-desktop-service-type)

                ;; To configure OpenSSH, pass an 'openssh-configuration'
                ;; record as a second argument to 'service' below.
                (service openssh-service-type)
                (service tor-service-type)
                (service cups-service-type)
		(service libvirt-service-type
			 (libvirt-configuration
			  (unix-sock-group "libvirt")))
		(service virtlog-service-type
			 (virtlog-configuration))
                (set-xorg-configuration
		 (xorg-configuration (keyboard-layout keyboard-layout)))

		(service zram-device-service-type
			 (zram-device-configuration
			  (priority 2)))
		
		(service tlp-service-type
			(tlp-configuration
			 (tlp-default-mode "BAT")
			 (start-charge-thresh-bat0 80)
			 (stop-charge-thresh-bat0 80)))

		(udev-rules-service 'disable-touchpad
				    (udev-rule
				     "80-disable-touchscreen.rules"
				     "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"056a\", ATTRS{idProduct}==\"00e6\", ATTR{authorized}=\"0\""))
				     
		
		(service mysql-service-type)
		(service httpd-service-type
       			 (httpd-configuration
			  (config
			   (httpd-config-file
			    (modules (cons*
				      (httpd-module
				       (name "proxy_module")
				       (file "modules/mod_proxy.so"))
				      (httpd-module
				       (name "proxy_fcgi_module")
				       (file "modules/mod_proxy_fcgi.so"))
				      %default-httpd-modules))
			    (extra-config (list "\
<FilesMatch \\.php$>
    SetHandler \"proxy:unix:/var/run/php-fpm.sock|fcgi://localhost/\"
</FilesMatch>"))))))
		(service php-fpm-service-type
			 (php-fpm-configuration
			  (socket "/var/run/php-fpm.sock")
			  (socket-group "httpd"))))
	  (modify-services %desktop-services
			   ;; enable wayland
			   (gdm-service-type config
					     =>
					     (gdm-configuration
					      (inherit config)
					      (wayland? #t)))
 			   ;; nonguix substitutes			 
			   (guix-service-type config
					      =>
					      (guix-configuration
					       (inherit config)
					       (substitute-urls
						(append (list "https://substitutes.nonguix.org")
							%default-substitute-urls))
					       (authorized-keys
						(append (list (local-file "./nonguix.pub"))
							%default-authorized-guix-keys))))
			   ;; Remove mozilla spyware
			   (delete geoclue-service-type)
			   ;; And useless modem service
			   )))
 
 (bootloader (bootloader-configuration
              (bootloader grub-bootloader)
              (targets (list "/dev/sda"))
              (keyboard-layout keyboard-layout)))
 (swap-devices (list (swap-space
		      (priority 1)
                      (target (uuid
                               "6c350d4e-050c-4801-902f-124f02835b7c")))))

 ;; The list of file systems that get "mounted".  The unique
 ;; file system identifiers there ("UUIDs") can be obtained
 ;; by running 'blkid' in a terminal.
 (file-systems (cons* (file-system
                       (mount-point "/")
                       (device (uuid
                                "ef6928b1-05f8-41d1-9e77-6a146fd5375b"
                                'btrfs))
                       (type "btrfs")) %base-file-systems)))
