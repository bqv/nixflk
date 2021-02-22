{ config, pkgs, lib, domains, ... }:

let
  hostAddress = "10.11.0.1";
  localAddress = "10.11.0.2";
in {
  containers.jellyfin =
    {
      autoStart = true;
      enableTun = true;
      privateNetwork = true;
      inherit hostAddress localAddress;

      config =
        { config, stdenv, ... }:

        {
          config = {
            nixpkgs.pkgs = pkgs;

            networking.firewall.enable = false;

            environment.systemPackages = with pkgs; [
              yq yj jq git
            ];

            services.jellyfin.enable = true;

            services.sonarr.enable = true;
            services.radarr.enable = true;
            services.lidarr.enable = true;
            services.bazarr.enable = true;
            services.jackett.enable = true;

            services.transmission = {
              enable = true;
              settings.dht-enabled = true;
              settings.download-dir = "/srv/ftp/torrents";
              settings.rpc-authentication-required = false;
              settings.rpc-bind-address = "0.0.0.0";
              settings.rpc-host-whitelist-enabled = false;
              settings.rpc-whitelist-enabled = false;
            };
            systemd.services.transmission = {
              environment.TRANSMISSION_WEB_HOME = pkgs.fetchFromGitHub {
                owner = "Secretmapper";
                repo = "combustion";
                rev = "d5ff91d4078b41bd3738542a20d802cd3ff6cc1e";
                sha256 = "gZ4YOKMsnYEWDLnh8OZNwEg1ZJioZsWrOcAjHLIyFYg=";
              };
              serviceConfig.ExecStartPost = "${pkgs.coreutils}/bin/chmod g+rwx /srv/ftp";
            };
          };
        };
      bindMounts = {
        "/srv/ftp" = {
          hostPath = "/srv/ftp";
          isReadOnly = false;
        };
      };
    };

  system.activationScripts.srv-ftp = ''
    mkdir -p /srv/ftp
    chmod g+rwx /srv/ftp
  '';

  systemd.tmpfiles.rules = [
    "d /srv/ftp 2777 root root"
  ]; #doas chmod a+rx /srv/ftp
}
