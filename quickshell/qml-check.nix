let
  lock = (builtins.fromJSON (builtins.readFile ../nixos/flake.lock)).nodes.nixpkgs.locked;
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${lock.rev}.tar.gz";
    sha256 = lock.narHash;
  }) { };
in
pkgs.mkShell {
  packages = [ pkgs.kdePackages.qtdeclarative pkgs.python3 ];
  QML_IMPORT_PATH = pkgs.lib.makeSearchPath "lib/qt-6/qml" [
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qtmultimedia
    pkgs.quickshell
  ];
}
