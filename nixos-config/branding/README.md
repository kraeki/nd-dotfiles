# ndos branding

The wordmark is **NDOS in Delta Corps Priest 1** — the FIGlet font the Omarchy
logo is drawn in — in Catppuccin Mocha teal, with a peach `❯` prompt.

`logo.txt` is the master. Regenerate it with the vendored Omarchy renderer:

```sh
~/.local/share/bin/ascii-logo-text NDOS > logo.txt
./ascii-to-svg logo.txt logo.svg     # exact, see below
./mk-wallpaper ../../dotfiles/hypr/.config/hypr/wallpapers/nd.png
```

The font draws with three glyphs only — `█` `▀` `▄` — so `ascii-to-svg` maps
every cell to a rectangle with **no approximation**: rasterising `logo.svg` back
to the 44x16 half-cell grid reproduces the ASCII pixel for pixel. That is why
the SVG is generated rather than traced, and why it must not be hand-edited.
One cell is 1x2 user units, the aspect the font is drawn for.

| Surface | Where | How |
| --- | --- | --- |
| Boot splash | `nixos-config/branding.nix` | Plymouth; PNG rendered from `logo.svg` at build time (`rsvg-convert -w 512`), quiet boot |
| Shell greeting | `dotfiles/fastfetch/` | the wordmark with fastfetch color markers (`logo.txt`), colors set in `config.jsonc` |
| Lock screen | `dotfiles/hypr/.config/hypr/hyprlock.conf` | dim `ndos ❯` text label — hyprlock labels are single-line, so the wordmark does not fit (background stays black to save power) |
| Wallpaper | `dotfiles/hypr/.config/hypr/wallpapers/nd.png` | `mk-wallpaper`: the mark at 10% opacity on the Mocha base, in the wpaperd rotation |

`ascii-to-svg` is pure Python; `mk-wallpaper` carries a `nix-shell` shebang for
ImageMagick + librsvg, which are not in the system closure.

Ported from the [ndos](../../../ndos) repo. There the boot splash is a
`nd.branding.enable` module option; here there is no `nd.*` namespace, so
`branding.nix` is unconditional — remove its import from `flake.nix` to get the
full text boot back.

`branding/` lives under `nixos-config/` rather than the repo root because the
flake root is `nixos-config/`, and Nix cannot reach paths outside it.
