{ config, lib, pkgs, ... }:

with lib; let
  cfg = config.programs.gpodder;
in {
  options = {
    programs.gpodder = {
      enable = mkEnableOption "Enable gpodder";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (pkgs.hiPrio (pkgs.writeShellScriptBin "gpodder" ''
        export GPODDER_HOME=${config.home.sessionVariables.GPODDER_HOME}
        exec ${gpodder}/bin/gpodder
      ''))
      gpodder mutagen normalize
    ];

    home.sessionVariables.GPODDER_HOME = "/srv/pod";
  };
}


