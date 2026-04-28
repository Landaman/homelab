{
  lib,
  config,
  ...
}:
{
  services.homebridge = {
    enable = true;
    openFirewall = true;
  };

  # Required so that Homebridge subrouters/service discovery works
  networking.firewall.trustedInterfaces = [ "wlan0" ];

  services.tailscale.tags = lib.mkAfter [ "tag:homebridge" ];
  services.tailscale.serve."8581" = {
    target = "http://localhost:${toString config.services.homebridge.uiSettings.port}";
    depends = [ "homebridge.service" ];
  };
}
