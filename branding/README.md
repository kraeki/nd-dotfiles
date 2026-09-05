# ndos branding

The wordmark is **NDOS in Delta Corps Priest 1** — the FIGlet font the Omarchy
logo is drawn in — in Catppuccin Mocha teal, with a peach `❯` prompt.

`logo.txt` is the master. Regenerate it with the vendored Omarchy renderer:

```sh
~/.local/share/bin/ascii-logo-text NDOS > logo.txt
./ascii-to-svg logo.txt logo.svg     # exact, see below
./mk-wallpaper ../dotfiles/hypr/.config/hypr/wallpapers/nd.png
./mk-lockmark  ../dotfiles/hypr/.config/hypr/branding/nd-lock.png
```

The font draws with three glyphs only — `█` `▀` `▄` — so `ascii-to-svg` maps
every cell to a rectangle with **no approximation**: rasterising `logo.svg` back
to the 44x16 half-cell grid reproduces the ASCII pixel for pixel. That is why
the SVG is generated rather than traced, and why it must not be hand-edited.
One cell is 1x2 user units, the aspect the font is drawn for.

| Surface | Where | How |
| --- | --- | --- |
| Boot splash | `modules/nixos/branding.nix` | Plymouth; PNG rendered from `logo.svg` at build time (`rsvg-convert -w 528`), quiet boot |
| Shell greeting | `dotfiles/fastfetch/` | the wordmark with fastfetch color markers (`logo.txt`), colors set in `config.jsonc` |
| Lock screen | `dotfiles/hypr/.config/hypr/branding/nd-lock.png` | `mk-lockmark`: the wordmark as an `image` widget in `hyprlock.conf` — labels are single-line, so eight rows of ASCII can only go in as a raster (background stays black to save power) |
| Wallpaper | `dotfiles/hypr/.config/hypr/wallpapers/nd.png` | `mk-wallpaper`: the mark at 10% opacity on the Mocha base, in the wpaperd rotation |

`ascii-to-svg` is pure Python; `mk-wallpaper` and `mk-lockmark` carry a
`nix-shell` shebang for ImageMagick + librsvg, which are not in the system
closure.

`mk-lockmark` bakes in what the hyprlock `image` widget cannot express: the
dim teal (there is no color or opacity key) and the trailing peach `❯` (drawn
from JetBrainsMono Nerd Font, since the chevron is not part of `logo.svg`). It
pads the result to a **square** — the widget scales by the lesser side, so a
square makes `size =` unambiguous and the render 1:1. `rounding = 0` is then
mandatory in `hyprlock.conf`: rounding defaults to `-1`, which crops the image
to a circle and would clip both ends off the wordmark.

**Render sizes must be whole multiples of the 44-cell grid** (528px for
Plymouth) — off-grid, cell edges land on fractional pixels and rsvg antialiases
visible hairline seams between the rects making up each glyph.

Turn the boot splash off with `nd.branding.enable = false;` (brings back the
full text boot).
