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
        specialArgs:
        nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs // {
            inherit secrets;
            hardware = nixos-hardware;
          };
          modules = [
            ./hardware/pi/hardware-pi02.nix
            ./common.nix
            ./components/pi-hole.nix
            (import ./components/tailscale-serve.nix {
              name = "pi-hole-tailscale-serve";
              description = "Serve the Pi-Hole web UI over Tailscale";
              localPort = 443;
              tailscalePort = 443;
              depends = "pihole-ftl.service";
            })
          ];
        };

    in
    {
      nixosConfigurations = {
        nine-cross-pi-hole = mkPiHole {
          systemName = "nine-cross-pi-hole";
        };

        adria-pi-hole = mkPiHole {
          systemName = "adria-pi-hole";
        };
      };
    };
}
