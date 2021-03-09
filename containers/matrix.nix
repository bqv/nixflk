{ config, pkgs, lib, usr, flake, ... }:

let
  hostAddress = "10.7.0.1";
  localAddress = "10.7.0.2";
in {
  services.postgresql.enable = true;
  services.postgresql.ensureUsers = [
    { name = "matrix-dendrite"; ensurePermissions."DATABASE \"matrix-dendrite\"" = "ALL PRIVILEGES"; }
  ];
  services.postgresql.ensureDatabases = [ "matrix-dendrite" ];

  containers.matrix =
    {
      autoStart = true;
      enableTun = true;
      privateNetwork = true;
      inherit hostAddress localAddress;

      config =
        { ... }:

        {
          #environment.memoryAllocator.provider = "jemalloc";

          environment.systemPackages = with pkgs; [ screen ];
          services.matrix-dendrite = rec {
            enable = true;
            #environmentFile = null;
            generatePrivateKey = true;
            generateTls = false;
            httpPort = 8008;
            settings = let
              mkDb = name: "postgresql://user:pass@hostname/dendrite-${name}";
            in {
              api_registration_disabled = false;
              server_name = "${usr.secrets.domains.srvc}:${httpPort}";
              kafka.naffka_database.connection_string = mkDb "naffka";
             #inherit (usr.secrets.matrix.synapse) registration_shared_secret;
             #public_baseurl = "https://matrix.${usr.secrets.domains.srvc}/";
             #database_type = "psycopg2";
             #database_args = {
             #  user = "matrix-dendrite";
             #  database = "matrix-dendrite";
             #  host = hostAddress;
             #};
            };
            tlsCert = "/var/lib/acme/${usr.secrets.domains.srvc}/fullchain.pem";
            tlsKey = "/var/lib/acme/${usr.secrets.domains.srvc}/key.pem";
          };

          networking.firewall.enable = false;

          users.users.matrix-synapse.extraGroups = [
            "keys"
          ];
         #users.users.construct.extraGroups = [
         #  "keys"
         #];
        };
      bindMounts = {
        "/var/lib/matrix-dendrite" = {
          hostPath = "/var/lib/dendrite";
          isReadOnly = false;
        };
        "/var/lib/matrix-synapse" = {
          hostPath = "/var/lib/synapse";
          isReadOnly = false;
        };
        "/var/lib/construct" = {
          hostPath = "/var/lib/construct";
          isReadOnly = false;
        };
        "/var/log/construct" = {
          hostPath = "/var/log/construct";
          isReadOnly = false;
        };
        "/var/lib/acme" = {
          hostPath = "/var/lib/acme";
          isReadOnly = true;
        };
      };
    };
}
