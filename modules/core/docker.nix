{ pkgs, config, ... }:

{
  virtualisation.docker = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker # Terminal UI for docker, similar to Docker Desktop
  ];
}
