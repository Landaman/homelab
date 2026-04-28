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
