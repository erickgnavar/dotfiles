{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "clipboard-picker";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = with pkgs; [
    pkg-config
    wrapGAppsHook4
    makeWrapper
  ];

  buildInputs = with pkgs; [
    gtk4
    glib
    json-glib
  ];

  buildPhase = ''
    runHook preBuild
    cc -O3 -Wall -Wextra -o clipboard-picker main.c \
      $(pkg-config --cflags --libs gtk4 gio-2.0 json-glib-1.0)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 clipboard-picker $out/bin/clipboard-picker

    wrapProgram $out/bin/clipboard-picker \
      --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.cliphist
        pkgs.wl-clipboard
        pkgs.sway
        pkgs.wtype
      ]}
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "GTK4 C clipboard history picker for Sway";
    mainProgram = "clipboard-picker";
    platforms = platforms.linux;
  };
}
