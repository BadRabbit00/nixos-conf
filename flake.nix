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

    # --- storytold Crafting Apps (photocraft, filmcraft, effectcraft, …) ---
    # В nixpkgs их пока нет (PR #571418/#571426/#571432 открыты и отстают на
    # несколько релизов). Флейк берёт официальные прибилженные tar.gz с GitHub
    # releases и чинит их autoPatchelf — без многочасовой сборки трёх Rust-монстров.
    # Обновляется ежедневно ботом; `nix flake update craftapps` подтянет новые версии.
    craftapps = {
      url = "github:olafkfreund/nix-craftapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- uv2nix: питон-локи -> нативные деривации ---------------------------
    # Нужны, чтобы colab-mcp (home/ai/mcp/colab-mcp.nix) собирался из
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

    # Гейт безопасности для CI (sec-scan, promptfoo, sec-pytest): свой публичный
    # репозиторий, его же копируемый workflow гоняют проекты без Nix.
    badrabbit-sec-scan = {
      url = "github:BadRabbit00/badrabbit-sec-scan";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ECC (Everything Claude Code) — свой форк апстрима affaan-m/ecc, ветка
    # badrabbit: апстрим + модуль `badrabbit` со своими скиллами, Nix-агентами и
    # командами, а также вся упаковка (nix/: стор, ecc-run/ecc-hook, выборка,
    # модели агентов, Nix-баннер). Здесь остаётся только раскладка по домам
    # агентов (home/ai/ecc). Обновление — `nix flake update ecc`.
    ecc = {
      url = "github:BadRabbit00/ECC/badrabbit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Одноразовая VM для активного аудита (sec-vm): без сети и общих папок.
    microvm = {
      url = "github:astro/microvm.nix";
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

    # Набор ИБ-инструментов для devShell `security` (garak — на CUDA-торче,
    # pkgsCuda с теми же настройками, что в home/generic-linux.nix).
    secTools = import ./home/ai/profiles/security/tools.nix {
      inherit (nixpkgs) lib;
      inherit inputs;
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      pkgsCuda = import nixpkgs {
        system = "x86_64-linux";
        config = { allowUnfree = true; cudaSupport = true; };
      };
    };
    # Стенд активного аудита: VM без сети; проверка изоляции — в flake check.
    secVm = import ./home/ai/profiles/security/vm {
      inherit inputs;
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    };
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
            # Чужой файл на месте HM-симлинка (например, правленный руками
            # ~/.claude/CLAUDE.md) уезжает в *.hm-bak, а не роняет активацию при загрузке.
            home-manager.backupFileExtension = "hm-bak";
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

    # Тяжёлый ML для профиля монтажа, вне PATH агента: nix develop .#montage-ml
    devShells.x86_64-linux.montage-ml = import ./home/ai/profiles/montage/ml-shell.nix {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config = { allowUnfree = true; cudaSupport = true; };
      };
    };

    # ИБ-инструменты вне профиля agy-sec, для claude/codex и рук:
    #   nix develop ~/nixos-conf#security
    # CI-гейт живёт отдельно: github:BadRabbit00/badrabbit-sec-scan.
    devShells.x86_64-linux.security =
      (import nixpkgs { system = "x86_64-linux"; }).mkShell {
        name = "security";
        packages = secTools.tools;
        shellHook = ''echo "security: sec-scan, semgrep, gitleaks, trivy, promptfoo, garak, zap… (см. home/ai/profiles/security/GEMINI.md)"'';
      };

    # nix run .#sec-vm -- up <проект>; изоляцию раннера проверяет nix flake check.
    packages.x86_64-linux.sec-vm = secVm.sec-vm;
    checks.x86_64-linux.sec-vm-isolation = secVm.isolationCheck;

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
            # Desktop apps render on the Intel iGPU; the RTX is kept for CUDA.
            defaultWrapper = "mesa";
            vulkan.enable = true;
          };
        })
      ];
    };
  };
}
