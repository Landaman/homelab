{
  modulesPath,
  hardware,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./sd-image.nix
    hardware.nixosModules.raspberry-pi-3 # Pi Zero 2W uses the same hardware module as Pi 3
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  system.stateVersion = "26.05";

  # Enable best swap space we can do
  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  sdImage = {
    extraFirmwareConfig = {
      # Give up VRAM for more Free System Memory
      # - Disable camera which automatically reserves 128MB VRAM
      start_x = 0;
      # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
      gpu_mem = 16;
    };
  };

  boot = {
    # Networking does not work properly without this https://github.com/raspberrypi/bookworm-feedback/issues/279
    extraModprobeConfig = ''
      options brcmfmac roamoff=1
      options brcmfmac feature_disable=0x82000
      options brcmfmac feature_disable=0x2000
    '';
  };
}
