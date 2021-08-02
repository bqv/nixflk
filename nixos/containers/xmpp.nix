{ config, pkgs, lib, usr, flake, ... }:

let
  hostAddress = "10.7.0.1";
  localAddress = "10.7.0.2";
  hostAddress6 = "fec0::ffff:10.7.0.1";
  localAddress6 = "fec0::ffff:10.7.0.2";
in {
 #services.postgresql = {
 #  enable = true;
 #  ensureUsers = [{
 #    name = "prosody";
 #    ensurePermissions."DATABASE \"prosody\"" = "ALL PRIVILEGES";
 #  }];
 #  ensureDatabases = [ "prosody" ];
 #};

  containers.xmpp =
    {
      autoStart = true;
      enableTun = true;
      privateNetwork = true;
      inherit hostAddress localAddress;
      inherit hostAddress6 localAddress6;

      config =
        { ... }:

        {
          nixpkgs = { inherit pkgs; };

          environment.systemPackages = with pkgs; [ jq vim ipfs ipfscat ];
          environment.variables = {
            IPFS_PATH = "${pkgs.runCommand "ipfs-path" {
              api = "/ip4/${usr.secrets.hosts.wireguard.ipv4.zeta}/tcp/5001";
              passAsFile = [ "api" ];
            } ''
              mkdir $out
              ln -s $apiPath $out/api
            ''}";
          };

          services.prosody = rec {
            enable = true;
            package = pkgs.prosody.override {
              withExtraLibs = [ pkgs.luaPackages.lpty ];
              withCommunityModules = [ "firewall" ];
            };
            admins = [ "qy@${usr.secrets.domains.srvc}" ];
            allowRegistration = true;
            c2sRequireEncryption = false;
            extraConfig = ''
              local_interfaces = { "*", "::" }
              Component "irc.${usr.secrets.domains.srvc}"
                  component_port = { 5347 }
                  component_secret = "${usr.secrets.weechat.credentials.password}"
            '';
            extraModules = [ "firewall" ];
            httpPorts = [ 5280 ];
            httpsPorts = [ 5281 ];
            group = "keys";
            modules.admin_adhoc = true;
            modules.admin_telnet = true;
            modules.bosh = true;
            modules.groups = true;
            modules.legacyauth = true;
            modules.watchregistrations = true;
            modules.websocket = true;
            muc = [{
              domain = "muc.${usr.secrets.domains.srvc}";
              maxHistoryMessages = 10000;
              name = "Zeta Prosody";
            }];
            ssl = {
              cert = "/var/lib/acme/${usr.secrets.domains.srvc}/fullchain.pem";
              key = "/var/lib/acme/${usr.secrets.domains.srvc}/key.pem";
            };
            uploadHttp = {
              domain = "xmpp.${usr.secrets.domains.srvc}";
            };
           #disco_items = [{
           #  url = "xmpp.${usr.secrets.domains.srvc}";
           #}];
            virtualHosts.srvc = {
              enabled = true;
              domain = usr.secrets.domains.srvc;
            };
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
