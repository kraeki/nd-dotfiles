# ~/nixos-config/flake.nix
{
  description = "ND's NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations."naptop" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/naptop/configuration.nix
          ./theme.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.kraeki = import ./home/kraeki/home.nix;
          }
        ];
      };
    };
}

