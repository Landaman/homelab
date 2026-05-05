{ lib, ... }:
{
  nix.settings = {
    experimental-features = lib.mkDefault "nix-command flakes";
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  boot.kernel.sysctl = {
    "kernel.panic" = 5;
  };
}
