{
  pkgs,
  lib,
  systemName,
  secrets,
  config,
  ...
}:
let
  systemSecrets = secrets."${systemName}";
  networkSecrets = secrets.networks.${systemSecrets.network};
in
{
  options = {
    services.tailscale.tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Tags to apply to this Tailscale device. Must start with tag:. The location tag is automatically applied.";
    };

    services.tailscale.machineServe = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            target = lib.mkOption {
              type = lib.types.str;
              description = "The local port number to serve over Tailscale";
            };

            depends = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "List of systemd units that should be started before this service";
            };
          };
        }
      );
      default = { };
      description = "List of services to serve over Tailscale HTTPS.";
    };
  };

  config = {
    systemd.services.tailscaled-generate-auth-key = {
      description = "Generate a tailscale auth key if necessary";

      before = [ "tailscaled-autoconnect.service" ];
      wantedBy = [ "tailscaled-autoconnect.service" ];
      after = [
        "tailescaled.service"
        "network-online.target"
        "time-sync.target"
      ];
      wants = [
        "tailescaled.service"
        "network-online.target"
        "time-sync.target"
      ];
      serviceConfig = {
        Type = "oneshot";
      };

      path = with pkgs; [
        tailscale
        jq
        curl
      ];
      script = ''
        set -o pipefail

        state="$(tailscale status --json --peers=false | jq -r '.BackendState')"

        # No need to do anything if we're already up
        if [[ ! "$state" =~ ^(NeedsLogin|NeedsMachineAuth|Stopped)$ ]]; then
          echo "Tailscale is already authenticated. Nothing to do."
          exit 0
        fi

        accessToken="$(curl --request POST \
          --url https://api.tailscale.com/api/v2/oauth/token \
          --header "Authorization: Basic $(echo -n "${secrets.tailscale.clientID}:${secrets.tailscale.clientSecret}" | base64 -w 0)" \
          --header 'content-type: application/x-www-form-urlencoded' \
          --data grant_type=client_credentials \
          --data scope=auth_keys | jq -r '.access_token')"

        deviceKey="$(curl 'https://api.tailscale.com/api/v2/tailnet/${secrets.tailscale.tailnet}/keys' \
          --request POST \
          --header 'Content-Type: application/json' \
          --header "Authorization: Bearer $accessToken" \
          --data '{
          "keyType": "auth",
          "description": "${systemName}",
          "capabilities": {
            "devices": {
              "create": {
                "reusable": false,
                "ephemeral": false,
                "preauthorized": false,
                "tags": [
                  ${lib.concatStringsSep "," (
                    lib.map (string: "\"${string}\"") (
                      config.services.tailscale.tags ++ [ "tag:${networkSecrets.tailscale.locationTag}" ]
                    )
                  )}
                ]
              }
            }
          },
          "expirySeconds": 60
        }' | jq -r '.key')"

        if [[ -z "$deviceKey" ]]; then
          echo "Failed to generate Tailscale device key"
          exit 1
        fi

        echo "$deviceKey" > /etc/tailnet-auth-key
        echo "Wrote device key to /etc/tailnet-auth-key"
      '';
    };

    services.tailscale = rec {
      enable = true;
      openFirewall = true;
      authKeyFile = "/etc/tailnet-auth-key";
      useRoutingFeatures = "server";
      extraSetFlags = [
        "--advertise-exit-node"
        "--advertise-routes=${lib.concatStringsSep "," networkSecrets.tailscale.accessibleSubnets}"
      ];
      extraUpFlags = extraSetFlags; # Without this, you can't use up after set runs
    };

    systemd.services.tailscale-machine-serve =
      let
        depends = (
          lib.flatten (lib.mapAttrsToList (_: value: value.depends) config.services.tailscale.machineServe)
        );
        serveConfig = config.services.tailscale.machineServe;
      in
      lib.mkIf config.services.tailscale.enable {
        description = "Set up the system to serve the configured services over Tailscale HTTPS";

        after = [
          "tailscaled.service"
          "tailscaled-autoconnect.service"
          "tailscaled-set.service"
        ]
        ++ depends;
        wants = [
          "tailscaled.service"
        ]
        ++ depends;
        wantedBy = [ "multi-user.target" ];

        serviceConfig.Type = "oneshot";

        path = with pkgs; [
          tailscale
          jq
        ];
        script =
          if serveConfig == { } then
            ''
              set -o pipefail
              echo "Serve config is empty, resetting all serves"
              tailscale serve reset
            ''
          else
            ''
              set -o pipefail

              # Get current serve status
              if ! current_status=$(tailscale serve status --json); then
                echo "Failed to get current serve status, assuming no serves are active"
                current_status='{}'
              fi

              # Extract currently served ports from TCP section
              current_ports=$(echo "$current_status" | jq -r '(.TCP // {}) | keys[]?')

              # Define desired ports from configuration
              desired_ports_array=(${lib.concatStringsSep " " (lib.attrNames serveConfig)})

              echo "Current ports: $current_ports"
              echo "Desired ports: ${lib.concatStringsSep " " (lib.attrNames serveConfig)}"

              # Turn off ports that are currently served but not in desired config
              for port in $current_ports; do
                port_found=false
                for desired_port in "''${desired_ports_array[@]}"; do
                  if [[ "$port" == "$desired_port" ]]; then
                    port_found=true
                    break
                  fi
                done
                if [[ "$port_found" == false ]]; then
                  echo "Turning off serve for port $port"
                  tailscale serve "$port" off
                fi
              done

              # Set up ports that are in desired config
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (port: serviceConfig: ''
                  echo "Setting up serve for port ${port} to target ${serviceConfig.target}"
                  # Check if already correctly configured
                  current_target=$(echo "$current_status" | jq -r '.TCP["${port}"].HTTPS // empty' 2>/dev/null || echo ''')
                  if [[ "$current_target" != "true" ]]; then
                    tailscale serve --https="${port}" --bg "${serviceConfig.target}"
                  else
                    echo "Port ${port} already served correctly"
                  fi
                '') serveConfig
              )}
            '';
      };
  };
}
