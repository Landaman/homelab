{
  lib,
  pkgs,
  ...
}:
{
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallWebserver = true;
    queryLogDeleter.enable = true;
    lists = [
      {
        enabled = true;
        type = "allow";
        url = "file://${
          pkgs.writeTextFile {
            name = "local-allowlist.txt";
            text = builtins.readFile ../pi-hole/allow.txt;
          }
        }";
        description = "Local Allowlist";
      }
      {
        enabled = true;
        type = "block";
        url = "file://${
          pkgs.writeTextFile {
            name = "local-blocklist.txt";
            text = builtins.readFile ../pi-hole/block.txt;
          }
        }";
        description = "Local Blacklist";
      }
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
