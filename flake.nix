{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  outputs =
    {
      nixpkgs,
      nixos-hardware,
      ...
    }:
    let
      secrets = builtins.fromJSON (builtins.readFile ./secrets.json);

      # Helper to make multiple pi systems with the same config
      mkPiHole =
        {
          systemName,
          specialArgs ? { },
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs // {
            inherit secrets systemName;
            hardware = nixos-hardware;
          };
          modules = [
            ./hardware/pi/hardware-pi02.nix
            ./common.nix
            ./components/pi-hole.nix
            {
              services.tailscale.serve = {
                "443" = {
                  target = "https+insecure://localhost:443";
                  depends = [ "pihole-ftl.service" ];
                };
              };
            }
          ]
          ++ extraModules;
        };

    in
    {
      nixosConfigurations = {
        nine-cross-pi-hole = mkPiHole {
          systemName = "nine-cross-pi-hole";
        };

        nine-cross-pi-hole-secondary = mkPiHole {
          systemName = "nine-cross-pi-hole-secondary";
          extraModules = [
            ./components/homebridge.nix
            {
              services.tailscale.serve."8581" = {
                target = "http://localhost:8581";
                depends = [ "homebridge.service" ];
              };
              # Required so that Homebridge subrouters/service discovery works
              networking.firewall.trustedInterfaces = [ "wlan0" ];
            }
          ];
        };

        adria-pi-hole = mkPiHole {
          systemName = "adria-pi-hole";
        };

        adria-pi-hole-secondary = mkPiHole {
          systemName = "adria-pi-hole-secondary";
        };
      };
    };
}
