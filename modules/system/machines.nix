{ config, pkgs, lib, extraModules, ... }:

let
  cfg = config.isolation;

  specialArgs = config._module.args;

  unaryStringFunctionType = with lib.types; addCheck anything (f:
    lib.isFunction f && lib.isString (f (lib.functionArgs f))
  ) // { description = "unary function returning string"; };
in {
  options.isolation = with lib; {
    makeHostAddress = mkOption {
      type = types.nullOr unaryStringFunctionType;
      example = literalExample ''{ id, ... }: "10.''${id}.0.1"'';
      default = null;
      description = "Function to make a host IPv4 from a unique scope index";
    };
    makeHostAddress6 = mkOption {
      type = types.nullOr unaryStringFunctionType;
      example = literalExample ''{ id, ... }: "fc00:''${id}::1"'';
      default = null;
      description = "Function to make a host IPv6 from a unique scope index";
    };
    makeLocalAddress = mkOption {
      type = types.nullOr unaryStringFunctionType;
      example = literalExample ''{ id, ... }: "10.''${id}.0.2"'';
      default = null;
      description = "Function to make a local IPv4 from a unique scope index";
    };
    makeLocalAddress6 = mkOption {
      type = types.nullOr unaryStringFunctionType;
      example = literalExample ''{ id, ... }: "fc00:''${id}::0"'';
      default = null;
      description = "Function to make a local IPv6 from a unique scope index";
    };
    scopes = mkOption {
      type = types.attrsOf (types.submodule ({ config, name, ... }: {
        options = {
          id = mkOption {
            type = types.ints.u8;
            description = "Scope identifier";
          };
          name = mkOption {
            type = types.addCheck types.str (name: lib.stringLength name < 12);
            default = name;
            description = "Scope name";
          };
          hostAddress = mkOption {
            type = types.str;
            description = "Scope IPv4 host address";
          };
          hostAddress6 = mkOption {
            type = types.str;
            description = "Scope IPv6 host address";
          };
          localAddress = mkOption {
            type = types.str;
            description = "Scope IPv4 local address";
          };
          localAddress6 = mkOption {
            type = types.str;
            description = "Scope IPv6 local address";
          };
          baseModules = mkOption {
            type = types.listOf types.anything;
            default = import (pkgs.path + "/nixos/modules/module-list.nix");
            description = "Scope base system modules";
          };
          extraModules = mkOption {
            type = types.listOf types.anything;
            description = "Extra scope modules";
          };
          nixos = mkOption {
            type = types.nullOr (types.submoduleWith {
              inherit specialArgs;
              modules = config.baseModules ++ config.extraModules ++ [(let
                inherit (config) name;
              in { config, ... }: {
                boot.isContainer = true;
                nixpkgs.system = pkgs.system;
                nixpkgs.pkgs = pkgs;
              })];
            });
            visible = false;
          };
          system = mkOption {
            type = types.package;
            default = config.nixos.system.build.toplevel;
            internal = true;
          };
        };
        config = {
          inherit extraModules;
          _module.args = { inherit (config) hostAddress hostAddress6 localAddress localAddress6; };
          nixos = {
            config = lib.mkMerge ([{
              networking.hostName = mkDefault (strings.sanitizeDerivationName name);
              networking.useDHCP = false;
              nix.optimise.automatic = false;
              documentation.nixos.enable = lib.mkForce false;
              users.mutableUsers = lib.mkForce true;
            }] ++ cfg.common.nixos);
          };
          hostAddress = lib.mkDefault (cfg.makeHostAddress { inherit (config) id name; });
          hostAddress6 = lib.mkDefault (cfg.makeHostAddress6 { inherit (config) id name; });
          localAddress = lib.mkDefault (cfg.makeLocalAddress { inherit (config) id name; });
          localAddress6 = lib.mkDefault (cfg.makeLocalAddress6 { inherit (config) id name; });
        };
      }));
      default = {};
      description = "Defined machine-like systems";
    };
    common.nixos = mkOption {
      type = with types; coercedTo anything singleton (listOf anything);
      default = {};
      description = "Common configuration between machines";
    };
    machines = mkOption {
      type = types.listOf types.anything;
      default = map (scope: {
        inherit (scope) id name;
        value = { inherit (scope) hostAddress localAddress system; };
      }) (builtins.attrValues cfg.scopes);
      internal = true;
    };
  };

  config = {
    containers = lib.mapAttrs (name: machine: {
      autoStart = true;
      enableTun = true;
      privateNetwork = true;
      inherit (machine) hostAddress localAddress;

      path = machine.system;
    }) (builtins.listToAttrs cfg.machines);

    assertions = lib.concatMap (attr: lib.mapAttrsToList (id: machines: {
      assertion = lib.any (m: m.id == null) machines || lib.length machines == 1;
      message = ''Overlap of container.*.${attr} between: ${
        lib.concatMapStringsSep "" (m: "\n  + ${m.name} = ${id}") machines}'';
    }) (lib.groupBy (x: toString x.id) (lib.mapAttrsToList (name: value: {
      inherit name value;
      id = value.${attr};
    }) config.containers))) [
      "hostAddress" "hostAddress6"
      "localAddress" "localAddress6"
    ];
  };
}
