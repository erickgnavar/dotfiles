# Edit this configuration file to define what should be installed on # your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.gc = {
    # Enable the automatic garbage collector
    automatic = true;
    # When to run the garbage collector
    dates = "00:00";
    # Delete old files
    options = "-d";
  };

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

  # Set your time zone.
  time.timeZone = "America/Mexico_City";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver = {
    xkb = {
      variant = "";
      layout = "us";
    };
  };

  # Remap caps lock to esc
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = ["*"];
        settings = {
          main = {
            capslock = "esc";
            leftmeta = "layer(alt)";
            leftalt = "layer(meta)";
          };
        };
      };
    };
  };

  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.enable = true;

  hardware.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.erick = {
    isNormalUser = true;
    description = "Erick Navarro";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ ];
  };

  programs.zsh.enable = true;

  users.users.erick.shell = pkgs.zsh;

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerdfonts
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  programs.hyprland.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    pamixer
    i3lock-fancy
    polybar
    nixpkgs-fmt
    wget
    vim
    rofi-wayland
    pavucontrol
    killall
    ripgrep
    emacsPackages.jinx
    aspell
    aspellDicts.en
    aspellDicts.es
    hunspell
    hunspellDicts.en_US
    tree-sitter
    fzf
    shfmt
    shellcheck
    pcmanfm
    tectonic
    wayland
    wlogout
    wl-clipboard
    networkmanagerapplet
    swaylock-effects
    nerdfetch
    fastfetch
    hyprshot
    swappy
    grim
    slurp
    cliphist
    telegram-desktop
    firefox
    brave
    alacritty
    tmux
    waybar
    keyd
    emacs-gtk
    localsend
    direnv
    bat
    eza
    unzip
    zsh
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
    nil
    biome
    brightnessctl
    libnotify
    dunst
    spotify
    tree
    btop
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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
