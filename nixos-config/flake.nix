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
    in {
      nixosConfigurations = {
        "naptop" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit home-manager; };
          modules = [
            ./hosts/naptop/configuration.nix
            ./theme.nix
            { nixpkgs.config.allowUnfree = true; }
          ];
        };
      };
    };
}

