;; Include local libraries
(add-to-load-path (dirname (current-filename)))

(use-modules (gnu)
	     (gnu system pam)
	     (nongnu packages linux)
	     (nongnu system linux-initrd)
	     ;; Local
	     (serax)
	     (containerise)
	     (gnu system file-systems)
	     (gnu build linux-container)
	     (guix gexp)
	     ;; Test
	     (python-test python-server)
	     ;; Blocklist
	     (gnu services base)
	     ;; Misc
	     (srfi srfi-1))

(use-package-modules wm search linux)
(use-service-modules cups desktop networking ssh xorg virtualization web
		     linux pm databases auditd)

;; PAM

;; auth sufficient pam_wheel.so trust use_uid
(define pam-su-allow-wheel
  (pam-extension
   (transformer
    (lambda (pam)
      (if (string=? "su" (pam-service-name pam))
	  (pam-service
	   (inherit pam)
	   (auth (cons (pam-entry
			(control "sufficient")
			(module (file-append linux-pam "/lib/security/pam_wheel.so"))
			(arguments '("trust" "use_uid")))
		       (pam-service-auth pam))))
	  pam)))))

;; Blocklist

(define (domains->block-list domains)
  (append-map (lambda (name)
		(map (lambda (addr)
		       (host addr name))
		     (list "0.0.0.0" "::")))
	      domains))

;; Operating sytem definition

(operating-system
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (cons* iwlwifi-firmware %base-firmware))

 (locale "en_US.utf8")
 (timezone "Europe/Warsaw")
 (keyboard-layout (keyboard-layout "us" #:options '("ctrl:swapcaps")))
 (host-name "x220")

 ;; Root implicit
 (users (cons* (user-account
		(name "maciej")
		(comment "Maciej Kalandyk")
		(group "users")
		(home-directory "/home/maciej")
		(supplementary-groups '("wheel" "netdev" "audio" "video" "libvirt")))
	       %base-user-accounts))

 (sudoers-file
  (plain-file "sudoers"
	      "root ALL=(ALL) NOPASSWD:ALL\n%wheel ALL=(ALL) NOPASSWD:ALL"))

 (packages (append (list
		    sway
		    (specification->package "nss-certs"))
		   %base-packages))

 ;; guix system search <service>
 (services
  (append (list (service gnome-desktop-service-type)
		(service openssh-service-type
			 (openssh-configuration
			  (x11-forwarding? #t)))
		(service tor-service-type)
		;; (containerise-service
		;;  (service python-server-service-type)
		;;  #:mounts (with-imported-modules
		;;	   '((gnu system file-systems)
		;;	     (gnu build linux-container))
		;;	   #~(begin
		;;	       (use-modules (gnu system file-systems)
		;;			    (gnu build linux-container))
		;;	       (cons* (specification->file-system-mapping "/tmp" #t)
		;;                       %container-file-systems))))
		;; (service ipfs-service-type)
		(service cups-service-type)
		(service libvirt-service-type
			 (libvirt-configuration
			  (unix-sock-group "libvirt")))
		(service virtlog-service-type
			 ;;(virtlog-configuration)
			 )
		(set-xorg-configuration
		 (xorg-configuration (keyboard-layout keyboard-layout)))

		(service zram-device-service-type
			 (zram-device-configuration
			  (size "2G")
			  (priority 2)))
		(service earlyoom-service-type
			 (earlyoom-configuration
			  (avoid-regexp "firefox|icecat|guix|emacs")))

		(service tlp-service-type
			 (tlp-configuration
			  (tlp-default-mode "BAT")
			  (start-charge-thresh-bat0 80)
			  (stop-charge-thresh-bat0 80)))
		(service thermald-service-type
			 ;;(thermald-configuration)
			 )

		;; auth sufficient pam_wheel.so trust use_uid
		(simple-service 'su-allow-wheel pam-root-service-type
				(list pam-su-allow-wheel))

		(simple-service 'block-undesirable-hosts hosts-service-type
				(domains->block-list
				 '("www.reddit.com"
				   "old.reddit.com"
				   "jbzd.com.pl"
				   "memy.jeja.pl"
				   "discord.com"
				   "www.facebook.com"
				   "balkansirl.net"
				   )))

		;;		(service auditd-service-type
		;;			 (auditd-configuration))

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
				      (httpd-module
				       (name "userdir_module")
				       (file "modules/mod_userdir.so"))
				      %default-httpd-modules))
			    (extra-config (list "\
<FilesMatch \\.php$>
    SetHandler \"proxy:unix:/var/run/php-fpm.sock|fcgi://localhost/\"
</FilesMatch>

Userdir \"Documents/Sites\"
Userdir disabled
Userdir enabled maciej

DirectoryIndex index.php index.phtml index.html index.htm"))))))
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
			   (delete modem-manager-service-type)
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
