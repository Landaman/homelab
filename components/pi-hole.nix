{
  lib,
  pkgs,
  ...
}:
let
  unboundPort = 5335;
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
          "127.0.0.1#${toString unboundPort}"
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

  # Needed since we use this below
  boot.kernel.sysctl."net.core.rmem_max" = 1048576;
  services.unbound = {
    enable = true;

    enableRootTrustAnchor = true;

    settings = {
      server = {
        verbosity = 2; # Log errors

        interface = [ "127.0.0.1" ];
        port = unboundPort;

        access-control = [ "127.0.0.1 allow" ];

        do-ip4 = true;
        do-ip6 = true;
        do-udp = true;
        do-tcp = true;

        # Trust glue only if it is within the server's authority
        harden-glue = true;

        # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
        harden-dnssec-stripped = true;

        # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
        # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
        use-caps-for-id = false;

        # Reduce EDNS reassembly buffer size.
        # IP fragmentation is unreliable on the Internet today, and can cause
        # transmission failures when large DNS messages are sent via UDP. Even
        # when fragmentation does work, it may not be secure; it is theoretically
        # possible to spoof parts of a fragmented DNS message, without easy
        # detection at the receiving end. Recently, there was an excellent study
        # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
        # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
        # in collaboration with NLnet Labs explored DNS using real world data from the
        # the RIPE Atlas probes and the researchers suggested different values for
        # IPv4 and IPv6 and in different scenarios. They advise that servers should
        # be configured to limit DNS messages sent over UDP to a size that will not
        # trigger fragmentation on typical network links. DNS servers can switch
        # from UDP to TCP when a DNS response is too big to fit in this limited
        # buffer size. This value has also been suggested in DNS Flag Day 2020.
        edns-buffer-size = 1232;

        # Perform prefetching of close to expired message cache entries
        # This only applies to domains that have been frequently queried
        prefetch = true;

        # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
        num-threads = 1;

        # Ensure kernel buffer is large enough to not lose messages in traffic spikes
        so-rcvbuf = "1m";

        private-address = [
          # Ensure privacy of local IP ranges
          "192.168.0.0/16"
          "169.254.0.0/16"
          "172.16.0.0/12"
          "10.0.0.0/8"
          "fd00::/8"
          "fe80::/10"

          # Ensure no reverse queries to non-public IP ranges (RFC6303 4.2)
          "192.0.2.0/24"
          "198.51.100.0/24"
          "203.0.113.0/24"
          "255.255.255.255/32"
          "2001:db8::/32"
        ];
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = [
            "9.9.9.9@853#dns.quad9.net"
            "149.112.112.112@853#dns.quad9.net"
            "2620:fe::fe@853#dns.quad9.net"
            "2620:fe::9@853#dns.quad9.net"
          ];
        }
      ];
    };
  };

  services.tailscale.tags = lib.mkBefore [ "tag:pi-hole" ];
}
