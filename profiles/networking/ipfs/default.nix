{ config, pkgs, ... }:

let
  cfg = config.services.ipfs;
in {
  environment.systemPackages = let
    toipfs = pkgs.writeScriptBin "toipfs" ''
      #!${pkgs.execline}/bin/execlineb -S1
      export EXECLINE_STRICT 2
      backtick -n -I dir { dirname $1 }
      backtick -n -I file { basename $1 }
      importas -i dir dir
      cd $dir
      importas -i file file
      if { touch .ipfs.$file }
      if { rm .ipfs.$file }
      backtick -n -i hash {
        pipeline { ${pkgs.ipfs}/bin/ipfs add -qr $file }
        tail -n 1
      }
      importas -i hash hash
      if { touch ${cfg.ipfsMountDir}/$hash }
      if -n { 
        if { rm -rf $file } ln -sf ${cfg.ipfsMountDir}/$hash $file
      }
      foreground { ln -sf ${cfg.ipfsMountDir}/$hash /tmp/toipfs.$file }
      foreground { echo Saved as /tmp/toipfs.$file }
      exit 1
    '';
    fromipfs = pkgs.writeScriptBin "fromipfs" ''
      #!${pkgs.execline}/bin/execlineb -S1
      export EXECLINE_STRICT 2
      backtick -n -i hash {
        pipeline { realpath $1 }
        xargs basename
      }
      importas -i hash hash
      if { touch ${cfg.ipfsMountDir}/$hash }
      if { rm -f $1 }
      cp -Lr --reflink=auto ${cfg.ipfsMountDir}/$hash $1
    '';
  in [ toipfs fromipfs ];

  services.ipfs = {
    enable = true;
    startWhenNeeded = true;
    enableGC = false;
    emptyRepo = true;
    autoMount = true;
    extraConfig = {
      DataStore = {
        StorageMax = "512GB";
      };
      Discovery = {
        MDNS.Enabled = true;
       #Swarm.AddrFilters = null;
      };
      Experimental.FilestoreEnabled = true;
    };
    gatewayAddress = "/ip4/127.0.0.1/tcp/4501";
  };

  systemd.services.ipfs = builtins.trace "ipfs config permissions still broken" {
    serviceConfig.ExecStartPost = "${pkgs.coreutils}/bin/chmod g+r /var/lib/ipfs/config";
  };
}
