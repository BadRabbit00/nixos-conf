{ config, pkgs, lib, ... }:

{
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # Fix deprecated option and enable container support
  hardware.nvidia-container-toolkit.enable = true;

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = true; # Required for stable CUDA/AI workloads

    # Fine-grained power management. Turns off GPU when not in use.
    powerManagement.finegrained = false; 

    # Use the NVidia open source kernel module.
    # Highly recommended for RTX 40/50 series. Full CUDA support included.
    open = true;

    # Enable the Nvidia settings menu.
    nvidiaSettings = true;

    # RTX 5060 requires the absolute latest drivers.
    package = config.boot.kernelPackages.nvidiaPackages.latest; 

    # Prime Configuration - OFFLOAD is what you want for Intel UI + NVIDIA Compute
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      # Bus IDs (Verify with lspci if it fails)
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Early loading for Blackwell architecture
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [ 
    "nvidia-drm.modeset=1" 
    "nvidia_drm.fbdev=1" 
    "NVreg_EnableGpuFirmware=1"
    "NVreg_DynamicPowerManagement=0x02"
    "pcie_aspm=off"
    "pci=realloc"
    "pci=nocsr"
    "pcie_port_pm=off"
    "nvidia.NVreg_EnableBacklightHandler=1"
    "acpi_backlight=native"
  ];

  # Enable Power Profiles Daemon for Fn+Q (Lenovo) support
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nvidia-offload" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec "$@"
    '')
  ];

  # --- Specialisation: AI / Compute Mode ---
  # В этом режиме мы НЕ включаем sync, чтобы интерфейс оставался на Intel
  # Но мы гарантируем, что NVIDIA готова к работе
  specialisation = {
    ai.configuration = {
      system.nixos.tags = [ "ai-compute" ];
      hardware.nvidia = {
        prime.offload.enable = lib.mkForce true;
        prime.sync.enable = lib.mkForce false;
        powerManagement.finegrained = lib.mkForce false;
      };
      # Никаких GBM_BACKEND=nvidia здесь, чтобы Hyprland сидел на Intel
    };
  };
}
