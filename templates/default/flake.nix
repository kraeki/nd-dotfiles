{
  description = "My machines on the nd system profile";

  inputs = {
    # git+https so the git credential helper (gh auth login) can serve the
    # distro while its repo is private; switch to github:kraeki/nd-dotfiles
    # if it goes public.
    nd.url = "git+https://github.com/kraeki/nd-dotfiles";
    # Ride nd's locked versions so you get the exact combination it tests.
    nixpkgs.follows = "nd/nixpkgs";
    home-manager.follows = "nd/home-manager";
  };

  outputs = { self, nd, nixpkgs, home-manager, ... }: {
    nixosConfigurations.mymachine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        nd.nixosModules.default
        { home-manager.sharedModules = [ nd.homeManagerModules.default ]; }
        ./hosts/mymachine
        { nixpkgs.config.allowUnfree = true; }
      ];
    };
  };
}
