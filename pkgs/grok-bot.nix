# Grok Bot (x.ai/bot): xAI's Electron desktop app for persistent cloud agents.
#
# NOT the same product as pkgs/grok.nix. That one is "Grok Build", the terminal
# coding agent (one static binary, artifacts under x.ai/cli). This is a GUI app
# whose agents keep running on xAI's infrastructure after the laptop closes.
# Nothing is shared: different artifact, different CDN, different binary name,
# different subscription.
#
# Shipped only as prebuilt desktop artifacts that self-update in place, so wrap
# the AppImage with appimageTools to get a real `grok-bot` binary plus the
# bundled .desktop/icons on NixOS -- same shape as pkgs/tldraw-offline.nix.
#
# Bumping: the artifacts live under a *commit sha*, not just a version, so
# `commit` and `version` and `hash` all move together. There is no public
# "latest" endpoint -- cursor.com/api/download answers for Cursor itself and
# ignores any product parameter -- so read both off the download page:
#   https://cursor.com/download/bot
# then: nix store prefetch-file <url>
{ lib, fetchurl, appimageTools }:

let
  pname = "grok-bot";
  version = "0.78.1";
  commit = "72e130b4e6be3fdc47b97e809b6b420908ce2dd8";
  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/${commit}/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-BQ11I8bvoEYmYROuLjsfPOlAlVSSwrlS/T5pi2DXP7g=";
  };
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Bundle the AppImage's own launcher entry + icons (8 sizes, 16..512) and
  # point Exec at the wrapped binary. Upstream ships
  # `Exec=AppRun --no-sandbox -- %U`; only AppRun is rewritten, so the
  # --no-sandbox stays. It has to: Chromium's sandbox needs a setuid
  # chrome-sandbox helper, which a store path cannot provide.
  #
  # The entry also registers two URL schemes (grokbot:, sand:) used to hand a
  # job off to the app, and StartupWMClass=grok-bot -- that is the Hyprland
  # window class, so it is what a window rule or launch-or-focus.sh keys off.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/${pname}.desktop \
      $out/share/applications/${pname}.desktop
    cp -r ${appimageContents}/usr/share/icons $out/share/
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
  '';

  meta = with lib; {
    description = "xAI's desktop app for persistent cloud agents; update via pkgs/grok-bot.nix, not in-app";
    homepage = "https://x.ai/bot";
    downloadPage = "https://cursor.com/download/bot";
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    # Proprietary, and gated behind an X Premium/Super/Ultra, SuperGrok or
    # Grok Business seat -- declared for the same reason pkgs/grok.nix does.
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
