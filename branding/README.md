# nd branding

The mark: a terminal window with a prompt — teal frame + chevron, peach
cursor (Catppuccin Mocha). `logo.svg` is the vector master; every surface
derives from it:

| Surface | Where | How |
| --- | --- | --- |
| Boot splash | `modules/nixos/branding.nix` | Plymouth; PNG rendered from `logo.svg` at build time (`rsvg-convert`), quiet boot |
| Shell greeting | `dotfiles/fastfetch/` | fastfetch with the ANSI mark (`logo.txt`, colors set in `config.jsonc`) |
| Lock screen | `dotfiles/hypr/.config/hypr/hyprlock.conf` | dim `nd ❯` label (background stays black to save power) |
| Wallpaper | `dotfiles/hypr/.config/hypr/wallpapers/nd.png` | mark at low opacity on the Mocha base, in the wpaperd rotation |

Turn the boot splash off with `nd.branding.enable = false;` (brings back the
full text boot).
