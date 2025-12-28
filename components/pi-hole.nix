{
  lib,
  systemName,
  secrets,
  ...
}:
let
  systemSecrets = secrets."${systemName}";
  networkSecrets = secrets.networks.${systemSecrets.network};
in
{
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallWebserver = true;
    queryLogDeleter.enable = true;
    lists = [
      {
        enabled = true;
        url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt";
        type = "block";
        description = "Hagezi Mutli PRO++";
      }
    ];

    settings = {
      dns = {
        listeningMode = "ALL";
        upstreams = [
          "9.9.9.9"
          "149.112.112.112"
          "2620:fe::fe"
          "2620:fe::9"
          networkSecrets.defaultGateway
        ];
      };
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [
      {
        port = 443;
        ssl = true;
      }
    ];
  };

  services.tailscale.tags = lib.mkBefore [ "tag:pi-hole" ];
}
