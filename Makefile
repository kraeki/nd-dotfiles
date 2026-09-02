HOST ?= naptop

# Symlink all dotfiles into $HOME
all:
	cd dotfiles && stow --verbose --target=$$HOME --restow */

# Remove all symlinked dotfiles
delete:
	cd dotfiles && stow --verbose --target=$$HOME --delete */

# Rebuild and switch to the NixOS configuration
switch:
	sudo nixos-rebuild switch --flake .#$(HOST)

# Rebuild without switching (sanity check)
build:
	sudo nixos-rebuild build --flake .#$(HOST)

# Update flake inputs, then rebuild and switch
upgrade:
	nix flake update
	sudo nixos-rebuild switch --flake .#$(HOST)
