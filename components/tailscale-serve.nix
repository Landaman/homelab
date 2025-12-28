{
  name,
  description,
  localPort,
  tailscalePort,
  depends,
}:
{
  lib,
  pkgs,
  config,
  ...
}:
{
  systemd.services.${name} = lib.mkIf config.services.tailscale.enable {
    description = description;

    after = [
      "tailscaled-autoconnect.service"
      depends
    ];
    wants = [
      "tailscaled-autoconnect.service"
      depends
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    path = with pkgs; [
      tailscale
      jq
    ];
    script = ''
      status="$(tailscale serve status --json | jq -r 'getpath(["TCP","${toString tailscalePort}","HTTPS"]) // empty')"
       if [ $status = "True" ]; then
         echo "${name} is already being served over Tailscale"
         exit 0
       fi

       tailscale serve --bg https+insecure://localhost:${toString localPort} --https=${toString tailscalePort}
    '';
  };
}
