all:
	cd dotfiles && stow --verbose --target=$$HOME --restow */

delete:
	cd dotfiles && stow --verbose --target=$$HOME --delete */

