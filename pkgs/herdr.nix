# herdr: terminal agent-multiplexer (github.com/herdrdev/herdr).
# Not in nixpkgs; upstream ships a prebuilt Linux binary that we patchelf
# onto the NixOS dynamic loader. Bump `version` + `hash` on updates
# (nix store prefetch-file <url>).
{ lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "herdr";
  version = "0.8.2";
  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
    hash = "sha256-l2FQoU1JDJSyQ+ouGn6y37Z/EuNrGC25CTb2co5q7PQ=";
  };
  dontUnpack = true;
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/herdr
    runHook postInstall
  '';
  meta = with lib; {
    description = "Terminal multiplexer / agent multiplexer for AI coding agents";
    homepage = "https://herdr.dev/";
    platforms = [ "x86_64-linux" ];
  };
}
