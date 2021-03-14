{ config, pkgs, lib, usr, flake, ... }:

let
  hostAddress = "10.7.0.1";
  localAddress = "10.7.0.2";
in {
  services.postgresql = {
    enable = true;
    ensureUsers = [{
      name = "prosody";
      ensurePermissions."DATABASE \"prosody\"" = "ALL PRIVILEGES";
    }];
    ensureDatabases = [ "prosody" ];
  };

  containers.xmpp =
    {
      autoStart = true;
      enableTun = true;
      privateNetwork = true;
      inherit hostAddress localAddress;

      config =
        { ... }:

        {
          nixpkgs = { inherit pkgs; };

          environment.systemPackages = with pkgs; [ jq vim ipfs ipfscat ];
          environment.variables = {
            IPFS_PATH = pkgs.runCommand "ipfs-path" {
              api = "/ip4/${usr.secrets.hosts.wireguard.ipv4.zeta}/tcp/5001";
              passAsFile = [ "api" ];
            } ''
              mkdir $out
              ln -s $apiPath $out/api
            '';
          };

          services.prosody = rec {
            enable = true;
            admins = [ "bqv@jix.im" ];
            allowRegistration = true;
            admin_adhoc = true;
            admin_telnet = true;
            httpPorts = [ 5280 ];
            httpsPorts = [ 5281 ];
            bosh = true;
            group = "keys";
            modules.legacyauth = true;
            modules.websocket = true;
            ssl.cert = "/var/lib/acme/${usr.secrets.domains.srvc}/fullchain.pem";
            ssl.key = "/var/lib/acme/${usr.secrets.domains.srvc}/key.pem";
          };

          networking.firewall.enable = false;
        };
      bindMounts = {
        "/var/lib/prosody" = {
          hostPath = "/var/lib/prosody";
          isReadOnly = false;
        };
        "/var/lib/acme" = {
          hostPath = "/var/lib/acme";
          isReadOnly = true;
        };
      };
    };
}
