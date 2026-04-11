{ pkgs, config, ... }:

{
  virtualisation.docker = {
    enable = true;
    # Use NVIDIA GPU in containers if NVIDIA is enabled
    enableNvidia = config.hardware.nvidia.modesetting.enable;
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker # Terminal UI for docker, similar to Docker Desktop
  ];
}
