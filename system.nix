{ pkgs, ... }: {
  # プライマリユーザー
  system.primaryUser = "shiroino";

  # Nix の設定
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Homebrew（GUI アプリ用）
  homebrew = {
    enable = true;
    casks = [
      "alt-tab"
      "ghostty"
      "keyclu"
      "raycast"
      "stats"
      "wezterm"
    ];
    onActivation.cleanup = "zap";
  };

  # macOS システム設定
  security.pam.services.sudo_local.touchIdAuth = true;

  # zsh
  programs.zsh.enable = true;
  programs.zsh.enableCompletion = false; # Home Manager 側で compinit -u を使う
  environment.pathsToLink = [ "/share/zsh" ];

  # nix-darwin のバージョン管理用
  system.stateVersion = 6;
}
