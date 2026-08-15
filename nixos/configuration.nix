# Edit this configuration file to define what should be installed on # your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
    ];

  nix.gc = {
    # Enable the automatic garbage collector
    automatic = true;
    # Remove generations older than two weeks once a week.
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # enable sound card
  boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];
  # clean tmp dir on restart
  boot.tmp.cleanOnBoot = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable Bluetooth and the Blueman applet service.
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Set your time zone.
  time.timeZone = "America/Mexico_City";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver = {
    xkb = {
      variant = "mac";
      layout = "us";
      # Use Left Alt for macOS-style accent sequences.
      options = "lv3:lalt_switch";
    };
  };

  # Remap caps lock to esc
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "esc";
            # Swap Meta and Alt for laptop keyboard layouts. This is not
            # required on desktop computers with a custom keyboard.
            # leftmeta = "layer(alt)";
            # leftalt = "layer(meta)";
          };
        };
      };
    };
  };

  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.package = pkgs.kdePackages.sddm;
  services.displayManager.sddm.theme = "sddm-astronaut-theme";
  services.displayManager.sddm.extraPackages = with pkgs.kdePackages; [
    qtmultimedia
  ];

  # enable keyring on unlock
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services."swaylock-plugin" = { };
  security.pam.services.wayvnc = { };
  # Give PipeWire realtime priority for low-latency, stable audio.
  security.rtkit.enable = true;

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Manage PipeWire devices, routing, and audio policy.
    wireplumber.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.erick = {
    isNormalUser = true;
    description = "Erick Navarro";
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
    packages = with pkgs; [ ];
  };

  programs.zsh.enable = true;
  programs.ssh.startAgent = true;
  services.gnome.gcr-ssh-agent.enable = false;

  users.users.erick.shell = pkgs.zsh;

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    noto-fonts-color-emoji
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swayidle
      waybar
    ];
  };

  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      # OBS requires an explicit output chooser for PipeWire screen capture.
      settings.screencast = {
        chooser_type = "simple";
        chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
      };
    };
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  };

  services.dbus.enable = true;

  # Let Gammastep determine sunrise and sunset from the current location.
  services.geoclue2 = {
    enable = true;
    appConfig.gammastep = {
      isAllowed = true;
      isSystem = false;
    };
  };

  # Enable Flatpak applications and configure Flathub system-wide.
  services.flatpak.enable = true;
  systemd.services.flatpak-setup = {
    description = "Configure the Flathub Flatpak remote";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig.Type = "oneshot";
    script = ''
      flatpak remote-add --system --if-not-exists \
        flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Enable the gnome-keyring secrets vault.
  # Will be exposed through DBus to programs willing to store secrets.
  services.gnome.gnome-keyring.enable = true;

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "adw-gtk3-dark";
          icon-theme = "Papirus-Dark";
          font-name = "Sans 10";
        };
      }
    ];
  };

  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Rotate wallpapers while the graphical session is active.
  systemd.user.services.wallpaper-rotate = {
    description = "Select the next desktop wallpaper";
    after = [ "graphical-session.target" ];
    path = with pkgs; [
      coreutils
      file
      findutils
      procps
      sway
      systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash %h/.config/sway/scripts/wallpaper.sh";
    };
  };

  systemd.user.timers.wallpaper-rotate = {
    description = "Rotate the desktop wallpaper every 30 minutes";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "1s";
      OnUnitActiveSec = "30m";
      Unit = "wallpaper-rotate.service";
    };
  };

  # Keep video wallpaper playback under systemd supervision.
  systemd.user.services.wallpaper-video = {
    description = "Video desktop wallpaper";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = ''${pkgs.mpvpaper}/bin/mpvpaper -o "hwdec=vaapi no-audio loop" "*" %h/.local/state/wallpaper/current-video'';
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  environment.etc."wayvnc/config".text = ''
    enable_auth=true
    enable_pam=true
  '';

  # Waybar starts and stops this service on demand.
  systemd.user.services.wayvnc = {
    description = "WayVNC remote desktop server";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    environment.WAYLAND_DISPLAY = "wayland-1";
    serviceConfig = {
      # Port 5900 is reserved by libvirt/QEMU's local VNC display.
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc -C /etc/wayvnc/config -Ldebug 0.0.0.0 5901";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  environment.systemPackages = with pkgs; [
    pamixer
    i3lock-fancy
    polybar
    # available theme config file are inside
    # /run/current-system/sw/share/sddm/themes/sddm-astronaut-theme/Themes
    (sddm-astronaut.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        substituteInPlace $out/share/sddm/themes/sddm-astronaut-theme/metadata.desktop \
          --replace "ConfigFile=Themes/astronaut.conf" "ConfigFile=Themes/pixel_sakura.conf"
      '';
    }))
    jq
    file # detect image and video wallpaper types
    bc # required for eww/net.sh calculations
    nixpkgs-fmt
    wget
    vim
    rofi
    rofimoji
    wayvnc # enable remote control
    pavucontrol
    killall
    ripgrep
    mutagen
    aspell
    aspellDicts.en
    aspellDicts.es
    hunspell
    hunspellDicts.en_US
    tree-sitter
    fzf
    shfmt
    shellcheck
    nautilus
    sushi # allow show previews in nautilus when pressing space
    tectonic
    wayland
    wlogout
    wl-clipboard
    wtype # sends paste shortcuts for the Sway clipboard menu
    glib
    adw-gtk3
    papirus-icon-theme
    nwg-look
    networkmanagerapplet
    swaylock-effects
    swaylock-plugin
    eww
    mpvpaper # for live wallpapers
    nerdfetch
    fastfetch
    # image annotation tool
    satty
    woomer # screen magnification tool
    hyprshot
    playerctl # to know what song is being played
    swappy
    grim
    slurp
    cliphist
    telegram-desktop
    firefox
    brave
    alacritty
    tmux
    emacs31-gtk3
    localsend
    mise
    bat
    eza
    unzip
    git
    delta
    gtk3
    zathura
    gnumake
    gcc
    cmake
    libtool
    libvterm
    clang-tools
    ruff
    pyright
    zig
    zls
    nixd
    biome
    brightnessctl
    gammastep # adjust screen color temperature based on sunrise and sunset
    libnotify
    swaynotificationcenter
    spotify
    tree
    btop
    htop
    obs-studio
    go
    gopls # LSP server
    gotools # includes goimports
    autotiling
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { #   enable = true; #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable tailscale
  services.tailscale.enable = true;

  networking.firewall = {
    enable = true;
    # Keep Tailscale exit nodes working with reverse-path filtering enabled.
    checkReversePath = "loose";
    # LocalSend uses TCP for transfers and UDP for device discovery.
    allowedTCPPorts = [ 53317 ];
    # Allow direct Tailscale peer connections and LocalSend discovery.
    allowedUDPPorts = [ config.services.tailscale.port 53317 ];
    # WayVNC listens globally but is reachable only through Tailscale.
    interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [ 5901 ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
