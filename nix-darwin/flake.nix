{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
    let
      configuration = { pkgs, config, ... }: {
        # Allow unfree packages
        nixpkgs.config.allowUnfree = true;

        fonts.packages = with pkgs; [
          jetbrains-mono
          nerdfonts
          open-dyslexic
        ];
        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        environment.systemPackages = with pkgs; [
          mkalias
          vim
          git
          # cmake and glibtool are required to compile libvterm in emacs
          cmake
          glibtool
          alacritty
          enchant
          eza
          tree
          go
          gopls
          gotools
          biome
          bat
          direnv
          tealdeer
          nerdfetch
          fastfetch
          fzf
          tmux
          macvim
          emacs30
          emacsPackages.jinx
          nixpkgs-fmt
          nixd
          shfmt
          google-cloud-sdk
          ripgrep
          # asdf-vm
          autojump
          docker
          colima
          wakatime-cli
          uv
          kubectl
          sqlfluff
          stylua
          # for emacs jinx package compilation
          pkg-config
          localsend
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
        ];

        homebrew = {
          enable = true;
          brews = [
            # libvterm is not available in nix for aarch64 so we
            # install it from homebrew
            "libvterm"
          ];
          casks = [
            "shortcat"
            "hammerspoon"
            "espanso"
            "krisp"
            "spotify"
            "ghostty"
          ];
        };

        # all available options are defined here https://daiderd.com/nix-darwin/manual/index.html
        system = {
          defaults = {
            dock.autohide = true;
            # Don't arrange spaces based on most recent use
            dock.mru-spaces = false;
            dock.persistent-apps = [
              "/System/Applications/Mail.app"
              "/System/Cryptexes/App/System/Applications/Safari.app"
              "/System/Applications/Messages.app"
              "/System/Applications/Notes.app"
              "${pkgs.macvim}/Applications/MacVim.app"
              "${pkgs.emacs30}/Applications/Emacs.app"
            ];
            finder.AppleShowAllExtensions = true;
            NSGlobalDomain.KeyRepeat = 2;
            NSGlobalDomain.AppleInterfaceStyle = "Dark";
            # disable natural scrolling
            NSGlobalDomain."com.apple.swipescrolldirection" = false;
            # Use scroll gesture with the Ctrl (^) modifier key to
            # zoom, this requires to have "Full disk access" in the
            # program which run nix-darwin command
            universalaccess.closeViewScrollWheelToggle = true;
          };
          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToEscape = true;
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
        services.nix-daemon.enable = true;
        # nix.package = pkgs.nix;

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        # Create /etc/zshrc that loads the nix-darwin environment.
        programs.zsh.enable = true; # default shell on catalina
        # programs.fish.enable = true;

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 5;

        # The platform the configuration will be used on.
        nixpkgs.hostPlatform = "aarch64-darwin";
      };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#simple
      darwinConfigurations."simple" = nix-darwin.lib.darwinSystem {
        modules = [ configuration ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."simple".pkgs;
    };
}
