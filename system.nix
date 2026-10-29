{ pkgs, ... }: {
  # プライマリユーザー
  system.primaryUser = "shiroino";

  # Nix の設定
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # eMudhra intermediate CA compromise (2026-10)
  # curl 2026-10-20 で G3/C1/C3 が除外済み。G1 も同系統のため併せて除外する。
  # 名前は certdata.txt の CKA_LABEL と一致させる必要がある。
  security.pki.caCertificateBlacklist = [
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
    "emSign Root CA - G1"
  ];

  # Fonts
  fonts.packages = with pkgs; [
    plemoljp-nf
  ];

  # Homebrew（GUI アプリ用）
  homebrew = {
    enable = true;
    casks = [
      "azookey"
      "blender"
      "ghostty"
      "karabiner-elements"
      "raycast"
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
