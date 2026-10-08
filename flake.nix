{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- uv2nix: питон-локи -> нативные деривации ---------------------------
    # Нужны, чтобы colab-mcp (home/programs/ai-mcp/colab-mcp.nix) собирался из
    # своего uv.lock целиком в /nix/store, а не резолвил зависимости через uv в
    # рантайме. Тройка ходит комплектом: pyproject-nix — базовые примитивы,
    # uv2nix — читатель lock-файлов, build-system-pkgs — сами build-backends
    # (hatchling и компания), которых в lock-файлах обычно нет.
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, ... }@inputs:
  let
    patoolFix = final: prev: {
      python314Packages = prev.python314Packages.override (old: {
        overrides = final.lib.composeExtensions (old.overrides or (_: _: {})) (pfinal: pprev: {
          patool = pprev.patool.overridePythonAttrs (oldAttrs: {
            doCheck = false;
          });
        });
      });
    };
    # nixpkgs 151fa4e: Tela 2026-07-07 fails noBrokenSymlinks on three
    # upstream aliases whose targets are missing. Keep all usable icons intact.
    telaFix = final: prev: {
      tela-circle-icon-theme = prev.tela-circle-icon-theme.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          for icon in \
            "$out"/share/icons/*/symbolic/apps/xsi-addon-symbolic.svg \
            "$out"/share/icons/*/scalable/apps/org.xfce.appfinder.svg; do
            if [[ -L "$icon" && ! -e "$icon" ]]; then
              rm "$icon"
            fi
          done
        '';
      });
    };
    # HM uses Catppuccin packages directly, not catppuccin.* options.
    # The NixOS Catppuccin module remains a system-only import.
    sharedHomeModules = [ inputs.sops-nix.homeManagerModules.sops ];
  in {
    nixosConfigurations = {
      badrabbitpc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          catppuccin.nixosModules.catppuccin
          ./hosts/desktop/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # specialArgs выше кормит только NixOS-модули; home-модулям inputs
            # надо передать отдельно, иначе ai-mcp не увидит uv2nix.
            home-manager.extraSpecialArgs = { isNixOS = true; inherit inputs; };
            home-manager.sharedModules = sharedHomeModules;
            home-manager.users.BadRabbit = import ./home/default.nix;
            
            nixpkgs.overlays = [ patoolFix telaFix ];
          }
        ];
      };
    };

    homeConfigurations."badrabbit@ARCH-BOX" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ patoolFix telaFix ];
        config.allowUnfree = true;
        config.nvidia.acceptLicense = true;
      };
      extraSpecialArgs = {
        isNixOS = false;
        inherit inputs;
        # Optional: absolute STRING pointing to a private age key outside the store.
        # null leaves Context7 usable without an API key.
        sopsAgeKeyFile = null;
      };
      modules = sharedHomeModules ++ [
        ./home/default.nix
        ({ lib, pkgs, ... }: {
          home.username = lib.mkForce "badrabbit";
          home.homeDirectory = lib.mkForce "/home/badrabbit";
          targets.genericLinux.enable = true;
          targets.genericLinux.nixGL = {
            packages = import ./arch/nixgl.nix { inherit pkgs; nixgl = inputs.nixgl; };
            defaultWrapper = "nvidia";
            vulkan.enable = true;
          };
        })
      ];
    };
  };
}
