{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, wrapGAppsHook3
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, glib
, gtk3
, libdrm
, libgbm
, libglvnd
, libpulseaudio
, libva
, libx11
, libxcb
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxkbcommon
, libxrandr
, nspr
, nss
, pango
, pipewire
, qt5
, qt6
, systemd
, vulkan-loader
, wayland
, xdg-utils
,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "helium";
  version = "0.20.1.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64_linux.tar.xz";
    hash = "sha256-ICP6RM76D70+GQcch+kNYSdfCLqPW0jVjCNSFVZem1M=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    (lib.getLib qt5.qtbase)
    (lib.getLib qt6.qtbase)
    stdenv.cc.cc.lib
    systemd
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  # Chromium loads these with dlopen rather than ELF DT_NEEDED entries.
  runtimeDependencies = map lib.getLib [
    gtk3
    libglvnd
    libpulseaudio
    libva
    pipewire
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/helium" "$out/bin" "$out/share/applications" \
      "$out/share/icons/hicolor/256x256/apps"
    cp -a . "$out/lib/helium/"

    install -Dm644 helium.desktop "$out/share/applications/helium.desktop"
    substituteInPlace "$out/share/applications/helium.desktop" \
      --replace-fail 'Exec=helium' "Exec=$out/bin/helium"
    install -Dm644 product_logo_256.png \
      "$out/share/icons/hicolor/256x256/apps/helium.png"

    # Use NixOS's graphics-driver-aware loader, not the bundled loader.
    rm "$out/lib/helium/libvulkan.so.1"
    ln -s "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" \
      "$out/lib/helium/libvulkan.so.1"
    substituteInPlace "$out/lib/helium/helium-wrapper" \
      --replace-fail 'CHROME_VERSION_EXTRA="custom"' 'CHROME_VERSION_EXTRA="nixos"'

    ln -s "$out/lib/helium/chromedriver" "$out/bin/chromedriver"

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/lib/helium/helium-wrapper" "$out/bin/helium" \
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      "''${gappsWrapperArgs[@]}"
  '';

  meta = {
    description = "Private, fast, and honest web browser based on Chromium";
    homepage = "https://helium.computer";
    changelog = "https://github.com/imputnet/helium-linux/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "helium";
  };
})
