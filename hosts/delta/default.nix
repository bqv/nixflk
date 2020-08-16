{ inputs, config, lib, pkgs, system, hosts, ... }:

{
  imports = [
    ../../profiles/meta/fatal-warnings.nix
    ../../profiles/misc/disable-mitigations.nix
    ../../profiles/misc/udev-nosettle.nix
    ../../profiles/misc/adblocking.nix
    ../../profiles/security/sudo.nix
    ../../profiles/security/apparmor
   #../../profiles/security/selinux
    ../../profiles/services/syncthing
    ../../profiles/services/aria2
    ../../profiles/services/guix
    ../../profiles/networking/ipfs
    ../../profiles/networking/bluetooth
    ../../profiles/networking/wireguard
    ../../profiles/networking/mdns.nix
   #../../profiles/sound/pipewire.nix
    ../../profiles/sound/pulse.nix
    ../../profiles/virtualization/anbox
    ../../profiles/graphical
   #../../profiles/bcachefs.nix
    ../../profiles/wayland.nix
    ../../profiles/weechat.nix
    ../../users/root.nix
    ../../users/bao.nix
    ./xserver.nix
    ./network.nix
    ./remote.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
      configurationLimit = 64;
      memtest86.enable = true;
    };
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ehci_pci" "ahci" "usbcore"
    "sd_mod" "sr_mod" "nvme" "amdgpu"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-intel" "amdgpu" "fuse" ];
  boot.kernelParams = [ "mce=3" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];
  boot.postBootCommands = ''
    echo 0000:04:00.0 > /sys/bus/pci/drivers/xhci_hcd/unbind
  ''; # usb4 is faulty

  fileSystems = let
    hdd = {
      device = "/dev/disk/by-uuid/f61d5c96-14db-4684-9bd6-218a468433b2";
      fsType = "btrfs";
    };
    ssd = {
      device = "/dev/disk/by-uuid/586c219f-a156-4088-8631-2a4a08bf9dc7";
      fsType = "btrfs";
    };
  in {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
    };

    "/var" = hdd // { options = [ "subvol=var" ]; };
    "/home" = hdd // { options = [ "subvol=home" ]; };
    "/srv" = hdd // { options = [ "subvol=srv" ]; };
    "/nix" = ssd // { options = [ "subvol=nix" "noatime" "nodiratime" "discard=async" ]; };
    "/gnu" = ssd // { options = [ "subvol=gnu" "noatime" "nodiratime" "discard=async" ]; };
    "/games" = hdd // { options = [ "subvol=games" ]; };
    "/run/hdd" = hdd // { options = [ "subvolid=0" ]; };
    "/run/ssd" = ssd // { options = [ "subvolid=0" "noatime" "nodiratime" "discard=async" ]; };

    ${config.services.ipfs.dataDir} = hdd // { options = [ "subvol=ipfs" ]; };

    "/boot" = {
      device = "/dev/disk/by-uuid/4305-4121";
      fsType = "vfat";
    };
  };
  systemd.services.srv-facl = {
    after = [ "srv.mount" ];
    script = "${pkgs.acl}/bin/setfacl -Rdm g:users:rwX /srv";
    wantedBy = [ "local-fs.target" ];
  };

  swapDevices = [
   #{ device = "/dev/disk/by-uuid/86868083-921c-452a-bf78-ae18f26b78bf"; }
  ];

  virtualisation.libvirtd.enable = true;
  virtualisation.virtualbox.host.enable = false;
  virtualisation.anbox.enable = builtins.trace "anbox: still f****d by kernel updates" false;
  systemd.network.networks = {
    "40-anbox0".networkConfig.ConfigureWithoutCarrier = true;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  headless = false;

  nix = {
    gc.automatic = true;
    gc.dates = "12:00";
    gc.options = "--delete-older-than 8d";

    autoOptimiseStore = false; # Disabled for speed
    optimise.automatic = true;
    optimise.dates = [ "17:30" "02:00" ];

    maxJobs = 16;
  };

  hardware.ckb-next.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.cpu = {
    intel.updateMicrocode = true;
    amd.updateMicrocode = true;
  };

  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      firefox-safe-x11 = pkgs.writeScript "firefox" ''
        env MOZ_ENABLE_WAYLAND=1 ${lib.getBin pkgs.large.firefox}/bin/firefox
      '';
      firefox-safe-wl = pkgs.writeScript "firefox" ''
        env -u MOZ_ENABLE_WAYLAND ${lib.getBin pkgs.large.firefox}/bin/firefox
      '';
      chromium-safe = "${lib.getBin pkgs.large.chromium}/bin/chromium";
      teams-safe = "${lib.getBin pkgs.teams}/bin/teams"; # broken a.f.
      mpv-safe = "${lib.getBin pkgs.mpv}/bin/mpv"; # broken too, apparently
    };
  };
  programs.vim.defaultEditor = true;
  programs.adb.enable = true;
  programs.tmux.enable = true;
  programs.xonsh.enable = true;

  services.disnix.enable = true;
  services.printing.enable = true;
  services.nix-index.enable = true;
  services.locate.enable = true;
  services.pcscd.enable = true;
  services.nixos-git = {
    enable = false;
    github = { owner = "bqv"; repo = "nixos"; };
    branch = "live";
    extraParams = {
      idle_fetch_timeout = 10;
    };
  };
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  nix.buildMachines = lib.optionals true [
    {
      hostName = hosts.wireguard.zeta;
      #sshUser = "nix-ssh";
      sshKey = "/etc/nix/id_zeta.ed25519";
      #system = "x86_64-linux";
      systems = ["x86_64-linux" "i686-linux" "armv6l-linux" "armv7l-linux"];
      maxJobs = 4;
      speedFactor = 4;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
  ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYNqRbITjMHmgD/UC87BISFTaw7Tq1jNd8X8i26x4b5 root@delta"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvcvk1nLYImKqjhL8HdAb1sM2vXcEGu+rMZJ8XIG4H7 bao@delta"
  ];

  environment.systemPackages = with pkgs; [
    clipmenu bitwarden bitwarden-cli pass protonmail-bridge

    ckb-next element-desktop nheko discord ripcord
    vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine
    qutebrowser firefox thunderbird electronmail mpv apvlv

    dunst catt termite rxvt_unicode
    steam obs-studio epsxe

    anbox #pmbootstrap

    (with hunspellDicts; hunspellWithDicts [ en_GB-large ])
    wineWowPackages.staging
  ];

  environment.etc."nix/id_zeta.ed25519".source = "/nix/keys/nix/id_zeta.ed25519";
  environment.etc."ssh/ssh_host_rsa_key".source = "/nix/keys/ssh/ssh_host_rsa_key";
  environment.etc."ssh/ssh_host_rsa_key.pub".source = "/nix/keys/ssh/ssh_host_rsa_key.pub";
  environment.etc."ssh/ssh_host_ed25519_key".source = "/nix/keys/ssh/ssh_host_ed25519_key";
  environment.etc."ssh/ssh_host_ed25519_key.pub".source = "/nix/keys/ssh/ssh_host_ed25519_key.pub";
  environment.etc."ssh/ssh_host_dsa_key".source = "/nix/keys/ssh/ssh_host_dsa_key";
  environment.etc."ssh/ssh_host_dsa_key-cert.pub".source = "/nix/keys/ssh/ssh_host_dsa_key-cert.pub";
  environment.etc."ssh/ssh_host_dsa_key.pub".source = "/nix/keys/ssh/ssh_host_dsa_key.pub";
  environment.etc."ssh/ssh_host_ecdsa_key".source = "/nix/keys/ssh/ssh_host_ecdsa_key";
  environment.etc."ssh/ssh_host_ecdsa_key-cert.pub".source = "/nix/keys/ssh/ssh_host_ecdsa_key-cert.pub";
  environment.etc."ssh/ssh_host_ecdsa_key.pub".source = "/nix/keys/ssh/ssh_host_ecdsa_key.pub";
  environment.etc."ssh/ssh_host_ed25519_key-cert.pub".source = "/nix/keys/ssh/ssh_host_ed25519_key-cert.pub";
  environment.etc."ssh/ssh_host_rsa_key-cert.pub".source = "/nix/keys/ssh/ssh_host_rsa_key-cert.pub";
  environment.etc."ssh/ssh_revoked_keys".source = "/nix/keys/ssh/ssh_revoked_keys";
  environment.etc."ssh/ssh_user-ca.pub".source = "/nix/keys/ssh/ssh_user-ca.pub";
  environment.etc."ssh/ssh_host-ca.pub".source = "/nix/keys/ssh/ssh_host-ca.pub";
  environment.etc."ssl/certs/mitmproxy.crt".source = "/nix/keys/ssl/certs/mitmproxy.crt";
  environment.etc."wireguard/private.key".source = "/nix/keys/wireguard/private.key";
}
