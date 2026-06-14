# ~/nixos-config/flake.nix
{
  description = "ND's NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, ... } @ inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        "naptop" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit home-manager; };
          modules = [
            nixos-hardware.nixosModules.framework-16-7040-amd
            ./hosts/naptop/configuration.nix
            ./theme.nix
            { nixpkgs.config.allowUnfree = true; }
          ];
        };
      };
    };
}
