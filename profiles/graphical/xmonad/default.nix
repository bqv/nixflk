{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dmenu xmobar taffybar
    maim rofi
  ];
  services.xserver = {
    windowManager = {
      xmonad.enable = true;
      xmonad.enableContribAndExtras = true;
      xmonad.extraPackages = hpkgs: [
        hpkgs.taffybar
        hpkgs.xmobar
      ];
    };
  };
}
