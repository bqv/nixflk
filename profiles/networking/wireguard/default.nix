{ config, pkgs, lib, usr, hosts, ... }:

let
  cfg = config.networking.wireguard;

  pubkeys = usr.secrets.wireguard.pubkeys;
  iptables = pkgs.iptables-nftables-compat;

  currentPeer = cfg.peers."${config.networking.hostName}";
in {
  options = {
    networking.wireguard = {
      prefixLength.ipv4 = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
      };
      prefixLength.ipv6 = lib.mkOption {
        type = lib.types.ints.between 0 128;
        default = 112;
      };
      currentPeer = lib.mkOption {
        type = lib.types.anything;
        default = config.networking.wireguard.peers.${config.networking.hostName};
      };
      peers = lib.mkOption {
        type = with lib.types; attrsOf (attrsOf (submodule {
          options = let
            peer = lib.types.submodule {
              options = {
                address = lib.mkOption {
                  type = lib.types.str;
                };
                host = lib.mkOption {
                  type = lib.types.str;
                };
                routes = lib.mkOption {
                  type = with lib.types; listOf str;
                  default = [];
                };
              };
            };
          in {
            publicKey = lib.mkOption {
              type = lib.types.str;
            };
            ipv4 = lib.mkOption {
              type = peer;
            };
            ipv6 = lib.mkOption {
              type = peer;
            };
          };

          config = {};
        }));
        default = {
          # Note: Wireguard won't retry DNS resolution if it fails
          zeta = {
            zeta = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.zeta;
                host = hosts.ipv4.zeta.address;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.zeta;
                host = "${hosts.ipv6.zeta.prefix}:1";
              };
              publicKey = pubkeys.zeta;
            };

            theta = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.theta;
                routes = [ "${hosts.wireguard.ipv4.theta}/24" ];
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.theta;
                routes = [ "${hosts.wireguard.ipv6.theta}/112" ];
              };
              publicKey = pubkeys.theta;
            };

            delta = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.delta;
                host = hosts.ipv4.r-home.address;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.delta;
                host = hosts.ipv6.r-home.address;
              };
              publicKey = pubkeys.delta;
            };

            phi = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.phi;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.phi;
              };
              publicKey = pubkeys.phi;
            };
          };
          theta = {
            zeta = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.zeta;
                host = hosts.ipv4.zeta.address;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.zeta;
                host = "${hosts.ipv6.zeta.prefix}:1";
              };
              publicKey = pubkeys.zeta;
            };

            theta = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.theta;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.theta;
              };
              publicKey = pubkeys.theta;
            };

            delta = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.delta;
                host = hosts.ipv4.r-home.address;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.delta;
                host = hosts.ipv6.r-home.address;
              };
              publicKey = pubkeys.delta;
            };

            phi = rec {
              ipv4 = {
                address = hosts.wireguard.ipv4.phi;
              };
              ipv6 = {
                address = hosts.wireguard.ipv6.phi;
              };
              publicKey = pubkeys.phi;
            };
          };
          delta = {
            zeta = rec {
              ipv4 = hosts.wireguard.ipv4.zeta;
              ipv6 = hosts.wireguard.ipv6.zeta;
              wideArea4 = [ hosts.ipv4.zeta.address ];
              wideArea6 = [ "${hosts.ipv6.zeta.prefix}:1" ];
              publicKey = pubkeys.zeta;
            };

            theta = rec {
              ipv4 = hosts.wireguard.ipv4.theta;
              ipv6 = hosts.wireguard.ipv6.theta;
              routes4.zeta = [ "${hosts.wireguard.ipv4.theta}/24" ];
              routes6.zeta = [ "${hosts.wireguard.ipv6.theta}/112" ];
              publicKey = pubkeys.theta;
            };

            delta = rec {
              ipv4 = hosts.wireguard.ipv4.delta;
              ipv6 = hosts.wireguard.ipv6.delta;
              wideArea4 = [ hosts.ipv4.r-home.address ];
              wideArea6 = [ hosts.ipv6.r-home.address ];
              localArea = [ hosts.lan.delta-wired hosts.lan.delta-wireless ];
              publicKey = pubkeys.delta;
            };

            phi = rec {
              ipv4 = hosts.wireguard.ipv4.phi;
              ipv6 = hosts.wireguard.ipv6.phi;
              localArea = [ hosts.lan.phi ];
              publicKey = pubkeys.phi;
            };
          };
          phi = {
            zeta = rec {
              ipv4 = hosts.wireguard.ipv4.zeta;
              ipv6 = hosts.wireguard.ipv6.zeta;
              wideArea4 = [ hosts.ipv4.zeta.address ];
              wideArea6 = [ "${hosts.ipv6.zeta.prefix}:1" ];
              publicKey = pubkeys.zeta;
            };

            theta = rec {
              ipv4 = hosts.wireguard.ipv4.theta;
              ipv6 = hosts.wireguard.ipv6.theta;
              routes4.zeta = [ "${hosts.wireguard.ipv4.theta}/24" ];
              routes6.zeta = [ "${hosts.wireguard.ipv6.theta}/112" ];
              publicKey = pubkeys.theta;
            };

            delta = rec {
              ipv4 = hosts.wireguard.ipv4.delta;
              ipv6 = hosts.wireguard.ipv6.delta;
              wideArea4 = [ hosts.ipv4.r-home.address ];
              wideArea6 = [ hosts.ipv6.r-home.address ];
              localArea = [ hosts.lan.delta-wired hosts.lan.delta-wireless ];
              publicKey = pubkeys.delta;
            };

            phi = rec {
              ipv4 = hosts.wireguard.ipv4.phi;
              ipv6 = hosts.wireguard.ipv6.phi;
              localArea = [ hosts.lan.phi ];
              publicKey = pubkeys.phi;
            };
          };
        };
      };
    };
  };

  config = {
    environment.systemPackages = [ pkgs.wgvanity ];
    environment.etc."wireguard/private.key".source = config.secrets.files.wireguard.file;

    networking.firewall.checkReversePath = "loose";
    networking.firewall.allowedUDPPorts =
      lib.mkIf (currentPeer ? "port") [ currentPeer.port ];

    networking.wireguard = {
      enable = true;
      prefixLength.ipv4 = 16;
      interfaces.wg0 = {
        ips = [
          "${currentPeer.ip}/${toString cfg.prefixLength.ipv4}"
        ];
        privateKeyFile = "${config.secrets.files.wireguard.file}";
        generatePrivateKeyFile = false;
        listenPort = currentPeer.port or 51820;

        peers = lib.mapAttrsToList (hostname: hostcfg: {
          inherit (hostcfg) publicKey;
          allowedIPs = [ "${hostcfg.ip}/32" ]
            ++ (hostcfg.routes.${config.networking.hostName} or []);
        } // (lib.optionalAttrs (builtins.length (endpointsOf hostcfg) > 0) {
          endpoint = "${builtins.head (endpointsOf hostcfg)}:${toString hostcfg.port or "51820"}";
          persistentKeepalive = 30;
        })) (lib.filterAttrs (hostname: _:
          peerable config.networking.hostName hostname
        ) cfg.peers);

        # Allow wireguard to route traffic to the internet
        postUp = ''
          ${iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
          ${iptables}/bin/iptables -t nat -A POSTROUTING -s ${currentPeer.ip}/24 -o eno1 -j MASQUERADE
        '';

        # Undo the above
        preDown = ''
          ${iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
          ${iptables}/bin/iptables -t nat -D POSTROUTING -s ${currentPeer.ip}/24 -o eno1 -j MASQUERADE
        '';
      };
    };

    systemd.services.wireguard-wg0.unitConfig.Before = [ "sshd.service" ];
    systemd.services.wireguard-wg1.unitConfig.Before = [ "sshd.service" ];

    secrets.files = {
      wireguard = {
        file = usr.secrets.keyDir + "/wireguard/${config.networking.hostName}.key";
       #user = "root";
       #group = "root";
      };
    };
  };
}
