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
      description = "Tags to apply to this Tailscale device. Must start with tag: . The location tag is automatically applied.";
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
  };
}
