{
  description = "nd — NixOS + Hyprland system, packaged as a reusable module library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    wayscriber.url = "github:devmobasa/wayscriber";
    wayscriber.inputs.nixpkgs.follows = "nixpkgs";
    # Handy: offline speech-to-text. Pinned to the v0.9.4 release tag (not main)
    # for reproducibility. Deliberately NOT `handy.inputs.nixpkgs.follows`:
    # (1) Handy is a large Rust build tested against its own locked nixpkgs, and
    # (2) the handy-computer.cachix.org cache (wired up in modules/nixos/core.nix)
    # is keyed on that nixpkgs, so following ours would guarantee a cache miss.
    # NOTE: as of this pin the cache has no x86_64 build for this rev, so the
    # first `nixos-rebuild` compiles ~1100 crates from source (~20-40 min, one
    # time — cached locally after). Bump this tag to pick up new Handy releases.
    handy.url = "github:cjpais/Handy/v0.9.4";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs: {
    # The distro as a library: import these from your own flake, set
    # `nd.enable = true`, and toggle individual `nd.*` options.
    nixosModules.default = import ./modules/nixos;
    homeManagerModules.default = import ./modules/home;

    nixosConfigurations = {
      "naptop" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          self.nixosModules.default
          ./hosts/naptop
          { nixpkgs.config.allowUnfree = true; }
        ];
      };
    };
  };
}
