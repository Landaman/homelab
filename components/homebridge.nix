{
  lib,
  ...
}:
{
  services.homebridge = {
    enable = true;
    openFirewall = true;
  };

  services.tailscale.tags = lib.mkAfter [ "tag:homebridge" ];
}
