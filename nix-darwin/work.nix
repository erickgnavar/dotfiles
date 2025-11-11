{ pkgs, config, ... }: {
  environment.systemPackages = with pkgs; [
    terraform
  ];

  homebrew = {
    casks = [
      "1password"
      "brave-browser"
      "chatgpt"
      "slack"
      "notion"
      "1password-cli"
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
