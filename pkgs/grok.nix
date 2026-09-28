# Grok CLI ("Grok Build", x.ai/bot): xAI's terminal coding agent.
# Not in nixpkgs, and upstream only ships `curl -fsSL https://x.ai/cli/install.sh
# | bash`, which drops a binary in ~/.grok/bin and self-updates in place. This
# packages the same artifact declaratively. Bump `version` + `hash` together
# (nix store prefetch-file <url>); the current stable is at
# https://x.ai/cli/stable, and `alpha` / `enterprise` are the other channels.
#
# Unlike pkgs/herdr.nix this needs NO autoPatchelfHook: the binary is
# static-pie linked ("file" says so, and there is no INTERP segment), so it
# runs on NixOS untouched. Do not add patchelf on the assumption that a
# prebuilt binary must need it -- re-check `file` after a version bump instead.
#
# Fetched as the .zst artifact: ~50 MiB against ~166 MiB uncompressed, for a
# byte-identical result.
{ lib, stdenvNoCC, fetchurl, zstd }:

stdenvNoCC.mkDerivation rec {
  pname = "grok";
  version = "1.0.41";
  src = fetchurl {
    url = "https://x.ai/cli/grok-${version}-linux-x86_64.zst";
    hash = "sha256-/RaWX7vOGyB+I0i4Njuu4o4gd6VX2rl3Yx0Rw0EhNSs=";
  };
  dontUnpack = true;
  nativeBuildInputs = [ zstd ];
  installPhase = ''
    runHook preInstall
    zstd -q -d $src -o grok
    install -Dm755 grok $out/bin/grok
    runHook postInstall
  '';
  # The store path is read-only, so the built-in `grok update` cannot work.
  # Say so rather than letting it fail obscurely.
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/grok --version | grep -q '${version}'
  '';
  meta = with lib; {
    description = "xAI's terminal coding agent (Grok Build); update via pkgs/grok.nix, not `grok update`";
    homepage = "https://x.ai/build";
    mainProgram = "grok";
    platforms = [ "x86_64-linux" ];
    # Proprietary binary, as with herdr.
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
