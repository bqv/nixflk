(define-module (rc system delta)
               #:use-module (rc utils)
               #:use-module (srfi srfi-1)
               #:use-module (gcrypt pk-crypto)
               #:use-module (guix packages)
               #:use-module (gnu)
               #:use-module (gnu system setuid)
               #:use-module (gnu system nss)
               #:use-module (nongnu system linux-initrd)
               #:use-module (rc system factors doas)
               #:use-module (rc system factors guix)
               #:use-module (rc system factors home)
               #:use-module (gnu services admin)
               #:use-module (gnu services desktop)
               #:use-module (gnu services sddm)
               #:use-module (gnu services shepherd)
               #:use-module (gnu services sound)
               #:use-module (gnu services ssh)
               #:use-module (gnu services sysctl)
               #:use-module (gnu services networking)
               #:use-module (gnu services nix)
               #:use-module (gnu services vpn)
               #:use-module (gnu services xorg)
               #:use-module (rc services biboumi)
               #:use-module (rc services home)
               #:use-module (rc services ipfs)
               #:use-module (rc services iwd)
               #:use-module (gnu packages admin)
               #:use-module (gnu packages android)
               #:use-module (gnu packages certs)
               #:use-module (gnu packages compression)
               #:use-module (gnu packages cpio)
               #:use-module (gnu packages curl)
               #:use-module (gnu packages disk)
               #:use-module (gnu packages display-managers)
               #:use-module (gnu packages file)
               #:use-module (gnu packages fonts)
               #:use-module (gnu packages glib)
               #:use-module (gnu packages gnome)
               #:use-module (gnu packages gnupg)
               #:use-module (gnu packages ipfs)
               #:use-module (gnu packages irc)
               #:use-module (gnu packages linux)
               #:use-module (gnu packages networking)
               #:use-module (gnu packages python)
               #:use-module (gnu packages radio)
               #:use-module (gnu packages rsync)
               #:use-module (gnu packages rust-apps)
               #:use-module (gnu packages screen)
               #:use-module (gnu packages shells)
               #:use-module (gnu packages skarnet)
               #:use-module (gnu packages ssh)
               #:use-module (gnu packages tmux)
               #:use-module (gnu packages version-control)
               #:use-module (gnu packages vim)
               #:use-module (gnu packages virtualization)
               #:use-module (gnu packages vpn)
               #:use-module (gnu packages web)
               #:use-module (gnu packages wm)
               #:use-module (gnu packages xiph)
               #:use-module (gnu packages xdisorg)
               #:use-module (gnu packages xorg)
               #:use-module (nongnu packages linux)
               #:use-module (rc packages biboumi)
               #:use-module (rc packages font-twitter-emoji)
               #:use-module (rc packages minecraft)
               #:use-module (rc packages nix)
               #:use-module (rc packages pipewire)
               #:use-module (rc packages usbreset)
               #:use-module (rc packages xmpppy)
               #:use-module (rc packages yggdrasil)
               #:export (os))

(define* (os #:rest home-envs)
  (operating-system
    (host-name "delta")
    (timezone "Europe/London")
    (locale "en_GB.utf8")
  
    (keyboard-layout (keyboard-layout "gb" #:options '("ctrl:nocaps")))
  
    (bootloader (bootloader-configuration
                  (bootloader grub-efi-bootloader)
                  (targets '("/boot/EFI"))
                  (terminal-outputs '(gfxterm vga_text console))
                  (keyboard-layout keyboard-layout)))
  
    (kernel linux)
    ;; CONFIG_IKCONFIG=y
    ;; CONFIG_IKCONFIG_PROC=y
    (kernel-arguments (cons*;"nomodeset"
                             "i915.modeset=0"
                             "modprobe.blacklist=pcspkr,dvb_usb_rtl28xxu"
                             (delete "quiet" %default-kernel-arguments)))
    (initrd microcode-initrd)
    (initrd-modules (cons*;"amdgpu"
                          ;"i915"
                           %base-initrd-modules))
    (firmware (cons* amdgpu-firmware linux-firmware
                     %base-firmware))
  
   ;(mapped-devices
   ; (list (mapped-device
   ;        (source (uuid "12345678-1234-1234-1234-123456789abc"))
   ;        ;; The UUID is that returned by 'cryptsetup luksUUID'.
   ;        (target "my-root")
   ;        (type luks-device-mapping))))
  
    (file-systems (let ((hdd (uuid "7aebd443-ae06-4ef4-927b-fb6816ef175b"))
                        (ssd (uuid "3bfa9fa3-46f5-47fa-b9bb-d2ba05801c09"))
                        (boot (uuid "4305-4121" 'fat)))
                    (cons* (file-system (device hdd)
                                        (mount-point "/")
                                       ;(dependencies mapped-devices)
                                        (needed-for-boot? #t)
                                        (type "btrfs")
                                        (options "subvol=guixsd"))
                           (file-system (device hdd)
                                        (mount-point "/home")
                                        (needed-for-boot? #t)
                                        (type "btrfs")
                                        (options "subvol=home"))
                           (file-system (device hdd)
                                        (mount-point "/var")
                                        (needed-for-boot? #t)
                                        (type "btrfs")
                                        (options "subvol=var"))
                           (file-system (device hdd)
                                        (mount-point "/srv")
                                        (type "btrfs")
                                        (options "subvol=srv"))
                           (file-system (device hdd)
                                        (mount-point "/games")
                                        (mount-may-fail? #t)
                                        (type "btrfs")
                                        (options "subvol=games"))
                           (file-system (device ssd)
                                        (mount-point "/gnu")
                                        (needed-for-boot? #t)
                                        (flags '(no-atime))
                                        (options "subvol=gnu")
                                        (type "btrfs"))
                           (file-system (device ssd)
                                        (mount-point "/var/guix")
                                        (mount-may-fail? #t)
                                        (options "subvolid=498") ; /gnu/var
                                        (type "btrfs"))
                           (file-system (device ssd)
                                        (mount-point "/nix")
                                        (flags '(no-atime))
                                        (options "subvol=nix")
                                        (mount-may-fail? #t)
                                        (type "btrfs"))
                           (file-system (device boot)
                                        (mount-point "/boot")
                                        (needed-for-boot? #t)
                                        (type "vfat"))
                           %base-file-systems)))
  
    (users (cons* (user-account
                    (name "leaf")
                    (password (crypt "alice" "$6$abc"))
                    (group "users")
                    (comment "Data User")
                    (shell (file-append zsh "/bin/zsh"))
                    (supplementary-groups '("wheel" "stem"
                                            "audio" "video" "kvm"
                                            "adbusers" "netdev" "yggdrasil")))
                  (user-account
                    (name "python")
                    (group "python")
                    (comment "Python Env")
                    (home-directory "/home/python")
                    (shell "/home/python/.guix-profile/bin/python")
                    (supplementary-groups '("stem")))
                  (user-account
                    (name "minecraft")
                    (group "games")
                    (home-directory "/var/lib/minecraft")
                    (system? #t))
                  (user-account
                    (name "biboumi")
                    (group "biboumi")
                    (system? #t))
                  (user-account
                    (name "s6log")
                    (group "s6log")
                    (comment "S6 log user")
                    (system? #t)
                    (uid 19)
                    (home-directory "/var/empty")
                    (shell (file-append shadow "/bin/nologin")))
                  %base-user-accounts))
  
    (groups (cons* (user-group
                     (name "games")
                     (system? #t))
                   (user-group
                     (name "biboumi")
                     (system? #t))
                   (user-group
                     (name "s6log")
                     (system? #t)
                     (id 992))
                   (user-group
                     (name "adbusers")
                     (system? #f))
                   (user-group
                     (name "python"))
                   (user-group
                     (name "stem"))
                   %base-groups))
  
    (packages (cons*
                nss-certs vim htop mosh ripgrep tmux go-ipfs file iwd
                git git-crypt git-remote-gcrypt (list git "send-email")
                neovim sshfs tree curl screen jq gvfs wireguard efibootmgr
                sway stumpwm awesome xinit xterm setxkbmap rsync gnupg python
                fish fish-foreign-env netcat rofi python-wrapper execline s6
                net-tools strace unzip gptfdisk usbreset s6-rc s6-linux-init
                font-dejavu font-twitter-emoji font-google-noto font-awesome
                %base-packages))
  
    (setuid-programs (cons*
                       (setuid-program
                         (program #~(string-append #$swaylock "/bin/swaylock")))
                       %setuid-programs))
 
    (sudoers-file (plain-file "sudoers" "\
                              root ALL=(ALL) ALL
                              %wheel ALL=(ALL) NOPASSWD:ALL\n"))
  
    (name-service-switch %mdns-host-lookup-nss)
  
    (services (cons* (service gnome-desktop-service-type)
                     (service xfce-desktop-service-type)
                     (service openssh-service-type
                              (openssh-configuration
                                (permit-root-login #t)
                                (openssh openssh-sans-x)))
                     (service unattended-upgrade-service-type
                              (unattended-upgrade-configuration
                                (schedule #~"00 12 * * *")
                                (channels
                                  (local-file "/etc/guix/channels.scm" "channels.scm"))
                                (operating-system-file
                                  (file-append (local-file "/srv/code/rc" "config-dir" #:recursive? #t)
                                               "/config.scm"))
                                (services-to-restart
                                  (list 'mcron))))
                     (service nix-service-type
                              (nix-configuration
                                (package nixUnstable)
                                (extra-config
                                  (list
                                    "experimental-features = nix-command flakes ca-references recursive-nix"
                                    "show-trace = true"))))
                     (service ipfs-service-type
                              (ipfs-configuration
                                (migrate #t)
                                (mount #t)
                                (settings '(("Experimental.AcceleratedDHTClient" "true")
                                            ("Experimental.FilestoreEnabled" "true")))
                                (args '("--enable-pubsub-experiment"
                                        "--enable-namesys-pubsub"))))
                     (service nftables-service-type
                              (nftables-configuration
                                (ruleset
                                  (plain-file "ruleset" 
                                              (@ (rc keys nftables) %ruleset)))))
                     (simple-service 'weechat shepherd-root-service-type
                                     (list (shepherd-service
                                             (documentation "Run the weechat daemon.")
                                             (provision '(weechat))
                                             (requirement '(networking))
                                             (start #~(make-forkexec-constructor
                                                        (list #$(file-append weechat "/bin/weechat-headless")
                                                              "-d" "/var/lib/weechat")
                                                        #:environment-variables
                                                        (append
                                                          (list
                                                            (string-append
                                                              "PYTHONPATH="
                                                              (string-join
                                                                (list
                                                                  #$(file-append python-xmpppy
                                                                                 "/lib/python3.8/site-packages"))
                                                                ":"))
                                                            "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
                                                            "SSL_CERT_DIR=/etc/ssl/certs")
                                                          (environ))))
                                             (stop #~(make-kill-destructor))
                                             (respawn? #f))))
                    ;(service wpa-supplicant-service-type
                    ;         (wpa-supplicant-configuration
                    ;           (interface "wlo1")
                    ;           (config-file "/etc/wpa_supplicant/wpa_supplicant.conf")))
                     (service sddm-service-type
                              (sddm-configuration
                                (auto-login-user "leaf")
                                (auto-login-session "sway.desktop")
                                (session-command
                                  (program-file
                                    "session-command"
                                    #~(let ((args (cdr (command-line))))
                                        (apply execlp
                                               (cons*
                                                 #$(file-append sddm "/share/sddm/scripts/wayland-session")
                                                 #$(file-append dbus "/bin/dbus-run-session")
                                                 "--"
                                                 args))
                                          #t)))
                                (xorg-configuration
                                  (xorg-configuration
                                    (keyboard-layout keyboard-layout)))))
                    ;(static-networking-service "enp4s0u1" "192.168.178.252"
                    ;                           #:gateway "192.168.178.1"
                    ;                           #:name-servers '("9.9.9.9"))
                     (service dhcp-client-service-type)
                    ;(service elogind-service-type
                    ;         (elogind-configuration))
                     (service wireguard-service-type
                              (wireguard-configuration
                                (addresses '("10.0.0.3/24"))
                                (peers
                                  (list
                                    (wireguard-peer
                                      (name "zeta")
                                      (endpoint "163.172.7.233:51820")
                                      (public-key "WbZqPcgSxWf+mNsWVbS+0JylysN9FKrRG9783wn1JAg=")
                                      (allowed-ips '("10.0.0.1/32"))
                                      (keep-alive 10))
                                    (wireguard-peer
                                      (name "theta")
                                      (endpoint "192.168.178.101:51820")
                                      (public-key "Itld9S83/URY8CR1ZsIfYRGK74/T0O5YbsHWcNpn2gE=")
                                      (allowed-ips '("10.0.0.2/32"))
                                      (keep-alive 10))
                                    (wireguard-peer
                                      (name "phi")
                                      (endpoint "192.168.178.135:51820")
                                      (public-key "kccZA+GAc0VStb28A+Kr0z8iPCWsiuRMfwHW391Qrko=")
                                      (allowed-ips '("10.0.0.4/32"))
                                      (keep-alive 10))))))
                     (service yggdrasil-service-type
                              (yggdrasil-configuration
                                (package yggdrasil)
                                (log-level 'debug)))
                     (extra-special-file "/etc/yggdrasil.conf" "/etc/yggdrasil-private.conf")
                     (service iwd-service-type)
                     (service bluetooth-service-type)
                     (service biboumi-service-type
                              (biboumi-configuration
                                (user "biboumi")
                                (home "/tmp")
                                (config
                                  (mixed-text-file "biboumi.cfg"
                                                   (let ((biboumi-password (@ (rc keys biboumi) password)))
                                                     #~(string-join
                                                         (map (lambda (p) (string-append
                                                                            (symbol->string (car p))
                                                                            "="
                                                                            (if (number? (cdr p))
                                                                                (number->string (cdr p))
                                                                                (cdr p))))
                                                              `((admin . "qy@xa0.uk")
                                                                (ca_file . "/etc/ssl/certs/ca-certificates.crt")
                                                                (db_name . "/var/lib/biboumi/biboumi.sqlite")
                                                                (hostname . "irc.xa0.uk")
                                                                (identd_port . 113)
                                                                (log_level . 1)
                                                                (password . ,#$biboumi-password)
                                                                (persistent_by_default . "false")
                                                                (policy_directory . ,(string-append #$biboumi "/etc/biboumi"))
                                                                (port . 5347)
                                                                (realname_customization . "true")
                                                                (realname_from_jid . "false")
                                                                (xmpp_server_ip . "10.0.0.1")))
                                                         "\n"))))))
                     (udev-rules-service 'pipewire-add-udev-rules
                                         pipewire-0.3)
                     (udev-rules-service 'android-add-udev-rules
                                         android-udev-rules)
                     (udev-rules-service 'rtl-sdr rtl-sdr)
                     (simple-service 'icecast-server shepherd-root-service-type
                                     (list (shepherd-service
                                             (documentation "Icecast2 service.")
                                             (provision '(icecast))
                                             (requirement '(networking))
                                             (start #~(lambda _
                                                        (let ((icecast (string-append #$icecast
                                                                                      "/bin/icecast")))
                                                          (fork+exec-command
                                                            (list icecast "-c" "/etc/icecast.xml")
                                                            #:environment-variables
                                                            (list "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
                                                                  "SSL_CERT_DIR=/etc/ssl/certs")))
                                                        #t)))))
                     (simple-service 'minecraft-server shepherd-root-service-type
                                     (list (shepherd-service
                                             (documentation "Minecraft Server.")
                                             (provision '(minecraft))
                                             (requirement '(networking))
                                             (start #~(lambda _
                                                        (let ((mc (string-append #$minecraft-server
                                                                                 "/bin/minecraft-server"))
                                                              (user (getpwnam "minecraft")))
                                                          (mkdir-p "/var/lib/minecraft")
                                                          (chmod "/var/lib/minecraft" #o755)
                                                          (chown "/var/lib/minecraft"
                                                                 (passwd:uid user) (passwd:gid user))
                                                          (fork+exec-command
                                                            (list mc "-Xmx2048M" "-Xms2048M")
                                                            #:user (passwd:uid user)
                                                            #:group (passwd:gid user)
                                                            #:directory "/var/lib/minecraft"
                                                            #:environment-variables
                                                            (list (string-append "HOME=" (passwd:dir user))
                                                                  "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
                                                                  "SSL_CERT_DIR=/etc/ssl/certs")))))
                                             (respawn? #f))))
                     (simple-service 'no-faulty-usb4 shepherd-root-service-type
                                     (list (shepherd-service
                                             (documentation "Disables the faulty usb4 device.")
                                             (provision '(disable-usb4))
                                             (start #~(lambda _
                                                        (false-if-exception
                                                          (with-output-to-file
                                                            "/sys/bus/pci/drivers/xhci_hcd/unbind"
                                                            (lambda _ (display "0000:04:00.0"))))
                                                        #t))
                                             (one-shot? #t))))
                     (simple-service 'fhs-shepherd-service shepherd-root-service-type
                       (list (shepherd-service
                               (documentation "S6 Container")
                               (provision '(fhs))
                               (requirement '())
                               (start #~(make-forkexec-constructor
                                          (list #$(program-file "fhs-start"
                                                    #~(let ((info-fd (begin
                                                                       (delete-file "/var/lib/containers/s6.json")
                                                                       (open-fdes "/var/lib/containers/s6.json"
                                                                                  (logior O_WRONLY O_CREAT)))))
                                                        (fcntl info-fd F_SETFL (logior O_NONBLOCK
                                                                                       (fcntl info-fd F_GETFL)))
                                                        (execlp
                                                          #$(file-append bubblewrap "/bin/bwrap") "bwrap"
                                                          "--dev-bind" "/var/lib/containers/s6" "/"
                                                          "--dev" "/dev"
                                                          "--dev-bind" "/dev/null" "/dev/log"
                                                          "--proc" "/proc"
                                                          "--bind" "/tmp" "/tmp"
                                                          "--ro-bind" "/sys" "/sys"
                                                          "--ro-bind" "/etc/resolv.conf" "/etc/resolv.conf"
                                                          "--ro-bind" "/etc/hostname" "/etc/hostname"
                                                          "--bind" "/home/leaf" "/home/leaf"
                                                          "--bind" "/srv" "/srv"
                                                          "--bind" "/run" "/run"
                                                          "--ro-bind" "/gnu" "/gnu"
                                                          "--ro-bind" "/var/guix" "/var/guix"
                                                          "--ro-bind" "/nix" "/nix"
                                                          "--unshare-pid" "--unshare-cgroup"
                                                          "--unshare-uts" "--unshare-ipc"
                                                          "--as-pid-1" "--info-fd" (number->string info-fd)
                                                          "--die-with-parent" "--new-session" "--chdir" "/"
                                                          "/usr/bin/env" "PATH=/bin:/sbin:$PATH"
                                                          "/sbin/init" "default"))))
                                          #:log-file "/var/log/s6.log"))
                               (stop #~(make-kill-destructor)))))
                     (simple-service 'fhs-profile-service profile-service-type
                       (list
                         (file->package
                           (program-file
                             "fhs"
                             #~(let ((args (cdr (command-line))))
                                 (setenv "PATH" (string-append "/bin:/sbin:" (getenv "PATH")))
                                 (apply execlp
                                        (cons* #$(file-append execline "/bin/backtick") "backtick"
                                               "-E" "pid"
                                               "jq" ".\"child-pid\"" "/var/lib/containers/s6.json"
                                               "" "doas" "nsenter" "-at" "$pid"
                                               args))
                                 #t))
                           "fhs" "0" #t)))
                     (fold (lambda (a b) (apply a (list b)))
                           (modify-services
                             %desktop-services
                             (sysctl-service-type config =>
                                                  (sysctl-configuration
                                                    (inherit config)
                                                    (settings (cons*
                                                                '("kernel.pid_max" . "4194304")
                                                                (sysctl-configuration-settings config)))))
                             (delete gdm-service-type)
                             (delete network-manager-service-type)
                             (delete pulseaudio-service-type)
                             (delete alsa-service-type))
                           (list modify-guix-service
                                 use-doas-services
                                 (apply-home-services home-envs)))))))
