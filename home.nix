{ pkgs, lib, ... }: {
  home.stateVersion = "25.05";
  home.username = "shiroino";
  home.homeDirectory = "/Users/shiroino";

  # パッケージ
  home.packages = with pkgs; [
    # Git
    git
    git-lfs
    gh
    gitleaks

    # エディタ
    neovim

    # 言語・ランタイム
    nodejs_22
    pnpm
    biome
    tenv

    # CLI ツール
    jq
    tree
    coreutils
    imagemagick

    # Nix リンター
    statix
    deadnix
  ];

  # npm グローバルパッケージ用 prefix（nix の store は read-only のため）
  home.file.".npmrc".text = ''
    prefix=~/.npm-global
  '';

  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs_22}/bin:$PATH"
    NPM_CONFIG_PREFIX="$HOME/.npm-global" ${pkgs.nodejs_22}/bin/npm install -g @aikidosec/safe-chain secretlint @secretlint/secretlint-rule-preset-recommend 2>/dev/null || true
  '';

  # Starship
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      extended = true;
      share = true;
    };
    completionInit = "autoload -U compinit && compinit -u";
    initContent = ''
      # 単語の入力途中でもTab補完を有効化
      setopt complete_in_word
      # 補完候補をハイライト
      zstyle ':completion:*:default' menu select=1
      # キャッシュの利用による補完の高速化
      zstyle ':completion::complete:*' use-cache true
      # 大文字、小文字を区別せず補完する
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      # 補完リストの表示間隔を狭くする
      setopt list_packed
      # コマンドの打ち間違いを指摘してくれる
      setopt correct
      SPROMPT="correct: $RED%R$DEFAULT -> $GREEN%r$DEFAULT ? [Yes/No/Abort/Edit] => "

      # PATH
      export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

      # Safe-chain
      source ~/.safe-chain/scripts/init-posix.sh
    '';
  };

  # Git
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "shiroino";
        email = "44906150+shiroinock@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
    };
  };

  # 設定ファイル
  xdg.configFile."starship.toml".source = ./config/starship.toml;
  xdg.configFile."wezterm/wezterm.lua".source = ./config/wezterm/wezterm.lua;
  xdg.configFile."wezterm/keybinds.lua".source = ./config/wezterm/keybinds.lua;
}
