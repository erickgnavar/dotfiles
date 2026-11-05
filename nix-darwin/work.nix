{ pkgs, config, ... }: {
  environment.systemPackages = with pkgs; [
    lima
    mutagen
    google-cloud-sql-proxy
  ];

  homebrew = {
    taps = [
      "Azure/kubelogin"
    ];
    brews = [
      "Azure/kubelogin/kubelogin"
    ];
    casks = [
      "1password"
      "brave-browser"
      "slack"
      "notion"
      "1password-cli"
      "tinycast"
    ];
  };

  # all available options are defined here https://daiderd.com/nix-darwin/manual/index.html
  system = {
    defaults = {
      dock.persistent-apps = [
        "/System/Applications/Mail.app"
        "/Applications/Brave Browser.app/"
        "/System/Applications/Notes.app"
        "/Applications/MacVim.app"
        "${pkgs.emacs}/Applications/Emacs.app"
      ];
    };
  };
}
