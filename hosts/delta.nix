args@{ nixpkgs, home, nur, self, lib, pkgs, system, ... }:

{
  imports =
    [
      ../legacy/delta/configuration.nix
      ../users/root
      ../users/bao
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot = {
      enable = true;
      configurationLimit = 8;
    };
  };

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbcore" "sd_mod" "sr_mod" "amdgpu" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-intel" "amdgpu" "fuse" ];
  boot.extraModulePackages = [ ];
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/f46f6fe4-c480-49f0-b3fb-22e61c57069c";
      fsType = "btrfs";
      options = [ "subvol=nixos" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/CEF4-EDD1";
      fsType = "vfat";
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/f46f6fe4-c480-49f0-b3fb-22e61c57069c";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/f46f6fe4-c480-49f0-b3fb-22e61c57069c";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

  fileSystems."/games" =
    { device = "/dev/disk/by-uuid/f46f6fe4-c480-49f0-b3fb-22e61c57069c";
      fsType = "btrfs";
      options = [ "subvol=games" ];
    };

  fileSystems."/var/run/btrfs" =
    { device = "/dev/disk/by-uuid/f46f6fe4-c480-49f0-b3fb-22e61c57069c";
      fsType = "btrfs";
      options = [ "subvolid=0" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/86868083-921c-452a-bf78-ae18f26b78bf"; }
    ];

  virtualisation.libvirtd.enable = true;
  virtualisation.virtualbox.host.enable = true;
  virtualisation.anbox.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # Enable bluetooth modules.
  hardware.bluetooth.enable = true;

  # Allow spectre locally for performance gains.
  security.mitigations = {
    disable = true;
    acceptRisk = true;
  };

  programs.firejail = {
    enable = true;
    wrappedBinaries = {
      firefox-safe = "${lib.getBin pkgs.firefox}/bin/firefox";
      mpv-safe = "${lib.getBin pkgs.mpv}/bin/mpv";
    };
  };
  programs.vim.defaultEditor = true;
  programs.adb.enable = true;

  services.locate.enable = true;
  services.nixos-git = {
    enable = true;
    github = { owner = "bqv"; repo = "nixos"; };
    branch = "live";
    extraParams = {
      idle_fetch_timeout = 10;
    };
  };
}
