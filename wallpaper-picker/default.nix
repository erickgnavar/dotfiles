{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "wallpaper-picker";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = with pkgs; [
    pkg-config
    wrapGAppsHook4
    makeWrapper
  ];

  buildInputs = with pkgs; [
    gtk4
    gdk-pixbuf
    glib
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
  ];

  buildPhase = ''
    runHook preBuild
    cc -O3 -Wall -Wextra -o wallpaper-picker main.c \
      $(pkg-config --cflags --libs gtk4 gdk-pixbuf-2.0)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 wallpaper-picker $out/bin/wallpaper-picker

    wrapProgram $out/bin/wallpaper-picker \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ffmpeg ]} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${pkgs.lib.makeSearchPath "lib/gstreamer-1.0" [
        pkgs.gst_all_1.gst-plugins-base
        pkgs.gst_all_1.gst-plugins-good
        pkgs.gst_all_1.gst-plugins-bad
        pkgs.gst_all_1.gst-libav
      ]}
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "GTK4 keyboard-driven image and video wallpaper picker";
    mainProgram = "wallpaper-picker";
    platforms = platforms.linux;
  };
}
