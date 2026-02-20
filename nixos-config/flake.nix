# ~/nixos-config/flake.nix
{
  description = "ND's NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";
    hyprdynamicmonitors.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, hyprdynamicmonitors, ... } @ inputs:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        "naptop" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit home-manager hyprdynamicmonitors; };
          modules = [
            ./hosts/naptop/configuration.nix
            ./theme.nix
            hyprdynamicmonitors.nixosModules.default
            { nixpkgs.config.allowUnfree = true; }
          ];
        };
      };
    };
}
