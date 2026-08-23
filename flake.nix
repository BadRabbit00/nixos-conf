{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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
  };

  outputs = { self, nixpkgs, home-manager, catppuccin, ... }@inputs: {
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
            home-manager.users.BadRabbit = import ./home/default.nix;
            
            # Наш временный хак для починки patool лежит в том же наборе атрибутов
            nixpkgs.overlays = [
              (final: prev: {
                python314Packages = prev.python314Packages.override (old: {
                  overrides = final.lib.composeExtensions (old.overrides or (_: _: {})) (pfinal: pprev: {
                    patool = pprev.patool.overridePythonAttrs (oldAttrs: {
                      doCheck = false;
                    });
                  });
                });
              })
            ];
          }
        ];
      };
    };
  };
}