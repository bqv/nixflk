{ config, lib, usr, pkgs, ... }:

{
  emacs-loader.dotnet = {
    demand = true;
    after = [ "csharp-mode" ];
    hook = [
      { csharp-mode-hook = "dotnet-mode"; }
    ];
    systemDeps = with pkgs; with dotnetCorePackages; [
      (combinePackages [
        sdk_2_1 sdk_3_0 sdk_3_1
      ]) azure-cli
    ];
  };
}
