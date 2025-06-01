{ pkgs, ... }:

let
  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pint 
    simpleeval 
    parsedatetime 
    pytz
  ]);
in

pkgs.writeShellScriptBin "ulauncher-wrapped" ''
  export PYTHONPATH=${pythonEnv}/lib/python3.12/site-packages
  exec ${pkgs.ulauncher}/bin/ulauncher "$@"
''
