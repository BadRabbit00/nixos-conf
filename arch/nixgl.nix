{ pkgs, nixgl }:

let
  # Compatibility with nvidia-open's version header and the pinned nixpkgs API.
  # The upstream detector still reads /proc locally on each impure evaluation.
  source = pkgs.applyPatches {
    name = "nixgl-source";
    src = nixgl;
    patches = [ ./nixgl-compat.patch ];
  };
  # Import against the same allowUnfree/acceptLicense package set as the apps.
  upstream = import source {
    inherit pkgs;
    enable32bits = false;
  };
  packages = if builtins ? currentTime then upstream.auto else
    throw "Arch NVIDIA auto-detection requires --impure on the NVIDIA host (after reboot).";
  eglPlatforms = pkgs.symlinkJoin {
    name = "nixgl-egl-platforms";
    paths = [ pkgs.egl-wayland pkgs.egl-gbm pkgs.egl-x11 ];
  };
  adapt = wrapper: wrapper.overrideAttrs (old: {
    text = builtins.replaceStrings
      [ "export LD_LIBRARY_PATH=" "nvidia_icd.x86_64.json" ]
      [ "export __EGL_EXTERNAL_PLATFORM_CONFIG_DIRS=${eglPlatforms}/share/egl/egl_external_platform.d\nexport LD_LIBRARY_PATH="
        "nvidia_icd.json" ]
      old.text;
  });
in
packages // {
  # Current NVIDIA uses external EGL platform JSON for Wayland/GBM. Keep that
  # lookup process-local too, instead of loading Arch's libraries into Nix apps.
  nixGLNvidia = adapt packages.nixGLNvidia;
  # Newer nixpkgs names the 64-bit Vulkan ICD nvidia_icd.json.
  nixVulkanNvidia = adapt packages.nixVulkanNvidia;
}
