{ pkgs, config, ... }: {
  environment.systemPackages = with pkgs; [
    xcodegen
    swift-format
    mutagen
    ffmpeg
  ];

  homebrew = {
    brews = [
      "llama.cpp"
      "odin"
      "ols"
    ];
    casks = [
      "krisp"
      "spotify"
      "alfred"
      "1password@7"
      "obs"
      "claude"
      "telegram"
      "firefox"
      "vlc"
      "utm"
      "brave-browser"
      "protonvpn"
      "signal"
      "freecad"
      "orcaslicer"
      "blender@lts"
      "imageoptim"
      "discord"
      "hiddenbar"
      "loopback"
      { "name" = "guanchzhou/tap/threemf"; trusted = true; }
      { "name" = "ruaylabs/tap/melocoton"; trusted = true; }
      "yubico-authenticator"
      "steam"
    ];
    masApps = {
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Pixelmator Pro" = 1289583905;
      "Things 3" = 904280696;
      "Xcode" = 497799835;
    };
  };

  # all available options are defined here https://daiderd.com/nix-darwin/manual/index.html
  system = {
    defaults = {
      dock.persistent-apps = [
        "/System/Applications/Mail.app"
        "/System/Cryptexes/App/System/Applications/Safari.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Notes.app"
        "/Applications/MacVim.app"
        "${pkgs.emacs}/Applications/Emacs.app"
      ];
    };
  };
}
