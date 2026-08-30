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

  outputs = { self, nixpkgs, home-manager, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import ./overlays/waybar.nix) ];
      };
    in {
    # The distro as a library: import these from your own flake, set
    # `nd.enable = true`, and toggle individual `nd.*` options.
    nixosModules.default = import ./modules/nixos;
    homeManagerModules.default = import ./modules/home;

    overlays.waybar = import ./overlays/waybar.nix;

    # The custom/compile-heavy derivations, exposed so CI can pre-build and
    # push them to the binary cache (see .github/workflows/build.yml and
    # modules/nixos/cache.nix). These are the exact derivations the system
    # and home configs use — wayscriber/handy mirror users/kraeki/home.nix.
    packages.${system} = {
      waybar = pkgs.waybar;
      herdr = pkgs.callPackage ./pkgs/herdr.nix { };
      tldraw-offline = pkgs.callPackage ./pkgs/tldraw-offline.nix { };
      wayscriber = inputs.wayscriber.packages.${system}.default.overrideAttrs (_: {
        doCheck = false;
      });
      handy = inputs.handy.packages.${system}.default;
    };

    # Every directory under hosts/ is a machine. install.sh relies on this:
    # a new machine gets a generated hosts/<name>/ (hardware probe + thin
    # default.nix) and is immediately buildable — no flake edit needed.
    nixosConfigurations = nixpkgs.lib.mapAttrs
      (name: _: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.nixosModules.home-manager
          self.nixosModules.default
          (./hosts + "/${name}")
          { nixpkgs.config.allowUnfree = true; }
        ];
      })
      (nixpkgs.lib.filterAttrs (_: type: type == "directory")
        (builtins.readDir ./hosts));
  };
}
