# tldraw offline (github.com/tldraw/tldraw-offline): a local, file-based
# infinite-canvas whiteboard desktop app (Electron). No account/server, boards
# live in .tldraw files on disk. Shipped only as a GitHub-release AppImage, so
# wrap it with appimageTools to get a real `tldraw-offline` binary plus the
# bundled .desktop/icons on NixOS. Bump `version` + `hash` on updates
# (nix store prefetch-file <url>).
{ fetchurl, appimageTools }:

let
  version = "1.11.0";
  src = fetchurl {
    url = "https://github.com/tldraw/tldraw-offline/releases/download/v${version}/tldraw-offline-linux-x86_64.AppImage";
    hash = "sha256-CUkGdHYz22gOYV5X+yAdB4yWi1Ii5zHJ53qgdnNEDgU=";
  };
  appimageContents = appimageTools.extractType2 {
    pname = "tldraw-offline";
    inherit version src;
  };
in
appimageTools.wrapType2 {
  pname = "tldraw-offline";
  inherit version src;
  # Bundle the AppImage's own launcher entry + icons, and point Exec at the
  # wrapped binary (upstream ships Exec=AppRun --no-sandbox %U).
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/@tldesktop.desktop \
      $out/share/applications/tldraw-offline.desktop
    cp -r ${appimageContents}/usr/share/icons $out/share/
    substituteInPlace $out/share/applications/tldraw-offline.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=tldraw-offline'
  '';
}
