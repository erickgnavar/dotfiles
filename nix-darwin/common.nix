{ pkgs, config, ... }: {
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    jetbrains-mono
    # this is required to show symbols properly
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
    open-dyslexic
  ];
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    mkalias
    vim
    git
    delta
    # cmake and glibtool are required to compile libvterm in emacs
    cmake
    just
    glibtool
    alacritty
    eza
    tree
    go
    gopls
    gotools
    biome
    bat
    mise
    xz
    typst
    typstyle
    # LSP for typst
    tinymist
    tealdeer
    nerdfetch
    fastfetch
    fzf
    tmux
    emacs
    nixpkgs-fmt
    nixd
    shfmt
    (google-cloud-sdk.withExtraComponents [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
    ripgrep
    docker-client
    colima
    wakatime-cli
    uv
    kubectl
    kubernetes-helm
    sqlfluff
    stylua
    defaultbrowser
    xmlformat
    yamllint
    jq
    pyright
    exiftool
    gnused
    imagemagick
    librsvg
    pngpaste
    (aspellWithDicts (dicts: with dicts; [ en en-computers es ]))
  ];

  homebrew = {
    enable = true;
    # when removing a brew application from this file it should
    # deleted from system as well
    onActivation.cleanup = "zap";
    brews = [
      # libvterm is not available in nix for aarch64 so we
      # install it from homebrew
      "libvterm"
      # this is required for mise be able to install erlang,
      # mise cannot identify openssl version installed in nix so
      # we need to use homebrew version to be able to use erlang
      # with no issues
      "openssl@3"
    ];
    casks = [
      "macvim-app"
      "hammerspoon"
      "espanso"
      "homerow"
      "localsend"
      "postgres-unofficial"
    ];
    masApps = {
      "Amphetamine" = 937984704;
      "Tailscale" = 1475387142;
      "The Unarchiver" = 425424353;
    };
  };

  # we need to specify primary user since nix-darwin 25.05
  system.primaryUser = "erick";

  # all available options are defined here https://daiderd.com/nix-darwin/manual/index.html
  system = {
    defaults = {
      dock.autohide = true;
      # Don't arrange spaces based on most recent use
      dock.mru-spaces = false;
      dock.orientation = "left";
      dock.showAppExposeGestureEnabled = true;
      finder.AppleShowAllExtensions = true;
      NSGlobalDomain.InitialKeyRepeat = 14;
      NSGlobalDomain.KeyRepeat = 2;
      NSGlobalDomain.AppleInterfaceStyle = "Dark";
      # use fn to access to media keys
      NSGlobalDomain."com.apple.keyboard.fnState" = true;
      # disable natural scrolling
      NSGlobalDomain."com.apple.swipescrolldirection" = false;
      # Use scroll gesture with the Ctrl (^) modifier key to
      # zoom, this requires to have "Full disk access" in the
      # program which run nix-darwin command
      universalaccess.closeViewScrollWheelToggle = true;
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerVertSwipeGesture = 2;
      };
      controlcenter.Sound = true;
      controlcenter.Bluetooth = true;
      controlcenter.NowPlaying = false;
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      # When performing a search, search the current folder by default
      FXDefaultSearchScope = "SCcf";
      DisableAllAnimations = true;
      NewWindowTarget = "PfHm";
      NewWindowTargetPath = "file://$\{HOME\}/";
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowStatusBar = true;
      ShowPathbar = true;
      WarnOnEmptyTrash = false;
    };
    "com.apple.Safari" = {
      # Privacy: don’t send search queries to Apple
      UniversalSearchEnabled = false;
      SuppressSearchSuggestions = true;
      # Prevent Safari from opening ‘safe’ files automatically after downloading
      AutoOpenSafeDownloads = false;
      AutoFillFromAddressBook = false;
      AutoFillCreditCardData = false;
    };
    "com.apple.print.PrintingPrefs" = {
      # Automatically quit printer app once the print jobs complete
      "Quit When Finished" = true;
    };
  };

  # link nix-apps into /Applications to be indexed by spotlight
  system.activationScripts.applications.text =
    let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = "/Applications";
      };

    in
    pkgs.lib.mkForce ''
      rm -fr /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';

  # Auto upgrade nix package and the daemon service.
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina
  # programs.fish.enable = true;

  # # Set Git commit hash for darwin-version.
  # system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
