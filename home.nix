{ pkgs, kandoPkgs, lib, config, ... }:
let
  codexFontFamily = "PlemolJP Console NF";

  # 自分の GitHub リポジトリに共通の設定(main の保護など)を入れるスクリプト
  repo-baseline = pkgs.writeShellApplication {
    name = "repo-baseline";
    runtimeInputs = [ pkgs.gh ];
    text = builtins.readFile ./scripts/repo-baseline.sh;
  };

  # PR の検査が落ち着くまで見張り、結果を1行ずつ出すスクリプト
  watch-prs = pkgs.writeShellApplication {
    name = "watch-prs";
    runtimeInputs = [ pkgs.gh pkgs.jq pkgs.coreutils ];
    text = builtins.readFile ./scripts/watch-prs.sh;
  };

  # watch-prs で緑になった PR をマージコミットでマージするスクリプト
  merge-when-green = pkgs.writeShellApplication {
    name = "merge-when-green";
    runtimeInputs = [ pkgs.gh watch-prs ];
    text = builtins.readFile ./scripts/merge-when-green.sh;
  };

  # push の前に、shiroinock/workflows の共通の静的ルールを流して直す(static-rules.yml のあるリポジトリだけ)
  static-rules-pre-push = pkgs.writeShellApplication {
    name = "static-rules-pre-push";
    runtimeInputs = [ pkgs.git pkgs.gnutar pkgs.diffutils pkgs.coreutils ];
    text = builtins.readFile ./scripts/git-hooks/static-rules-pre-push.sh;
  };

  # core.hooksPath に置く共通のフック。共通の処理のあと、リポジトリ自身の hooks/<名前> を呼ぶ。
  # 置くだけで git のふるまいが変わる push-to-checkout と proc-receive だけは入れない。
  git-hook-dispatch = pkgs.writeShellApplication {
    name = "git-hook-dispatch";
    runtimeInputs = [ pkgs.git pkgs.git-lfs pkgs.coreutils pkgs.gnugrep static-rules-pre-push ];
    text = builtins.readFile ./scripts/git-hooks/dispatch.sh;
  };
  gitHookNames = [
    "applypatch-msg" "pre-applypatch" "post-applypatch"
    "pre-commit" "pre-merge-commit" "prepare-commit-msg" "commit-msg" "post-commit"
    "pre-rebase" "post-checkout" "post-merge" "pre-push" "post-rewrite"
    "reference-transaction" "post-index-change" "pre-auto-gc" "sendemail-validate"
    "pre-receive" "update" "post-receive" "post-update"
    "p4-changelist" "p4-prepare-changelist" "p4-post-changelist" "p4-pre-submit"
  ];
  git-hooks = pkgs.runCommand "git-hooks" { } (
    "mkdir -p $out\n"
    + lib.concatMapStrings (n: "ln -s ${lib.getExe git-hook-dispatch} $out/${n}\n") gitHookNames
  );
in
{
  home.stateVersion = "25.05";
  home.username = "shiroino";
  home.homeDirectory = "/Users/shiroino";

  # emSign を除外した nix-darwin 管理の CA バンドルを、Nix 外のツールにも使わせる。
  # NODE_OPTIONS=--use-openssl-ca は Claude Code(公式インストーラー版)の TLS を壊すため設定しない。
  home.sessionVariables = {
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    CURL_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    GIT_SSL_CAINFO = "/etc/ssl/certs/ca-certificates.crt";
    REQUESTS_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    PIP_CERT = "/etc/ssl/certs/ca-certificates.crt";
  };

  # パッケージ
  home.packages = with pkgs; [
    # Git
    git
    git-lfs
    gh
    gitleaks

    # GUI アプリ（Nix管理）
    kandoPkgs.kando

    # エディタ
    neovim

    # 言語・ランタイム
    nodejs_22
    pnpm
    python3
    uv
    ruby_3_4
    biome
    tenv

    # CLI ツール
    ripgrep
    jq
    tree
    coreutils
    ffmpeg
    imagemagick

    # Nix リンター
    statix
    deadnix

    # 自作スクリプト
    repo-baseline
    watch-prs
    merge-when-green
  ];

  # npm グローバルパッケージ用 prefix（nix の store は read-only のため）
  home.file.".npmrc".text = ''
    prefix=~/.npm-global
  '';

  home.file.".safe-chain/config.json".text = builtins.toJSON {
    minimumPackageAgeHours = 48;
  };

  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.nodejs_22}/bin:$PATH"
    NPM_CONFIG_PREFIX="$HOME/.npm-global" ${pkgs.nodejs_22}/bin/npm install -g @aikidosec/safe-chain@1.5.3 secretlint @secretlint/secretlint-rule-preset-recommend 2>/dev/null || true
  '';

  home.activation.configureCodexFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python ${./config/codex/apply-fonts.py} \
      "$HOME/.codex/config.toml" \
      "${codexFontFamily}"
  '';

  home.activation.configureInputSources = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python ${./config/macos/configure-input-sources.py} \
      "${config.home.homeDirectory}/Library/Preferences/com.apple.HIToolbox.plist"
    /usr/bin/killall cfprefsd 2>/dev/null || true
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

      # Homebrew (managed by nix-darwin)
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      # Apollo Rover / Router
      [ -f "$HOME/.rover/env" ] && source "$HOME/.rover/env"
      [ -f "$HOME/.router/env" ] && source "$HOME/.router/env"

      # Safe Chain
      printSafeChainWarning() {
        printf "\033[43;30mWarning:\033[0m safe-chain is not available to protect you from installing malware. %s will run without it.\n" "$1"
        printf "Install safe-chain by using \033[36mnpm install -g @aikidosec/safe-chain\033[0m.\n"
      }

      wrapSafeChainCommand() {
        local original_cmd="$1"

        if ! type -f "$original_cmd" > /dev/null 2>&1; then
          command "$@"
          return $?
        fi

        if command -v safe-chain > /dev/null 2>&1; then
          safe-chain "$@"
        else
          printSafeChainWarning "$original_cmd"
          command "$@"
        fi
      }

      npx() { wrapSafeChainCommand "npx" "$@"; }
      yarn() { wrapSafeChainCommand "yarn" "$@"; }
      pnpm() { wrapSafeChainCommand "pnpm" "$@"; }
      pnpx() { wrapSafeChainCommand "pnpx" "$@"; }
      rush() { wrapSafeChainCommand "rush" "$@"; }
      rushx() { wrapSafeChainCommand "rushx" "$@"; }
      bun() { wrapSafeChainCommand "bun" "$@"; }
      bunx() { wrapSafeChainCommand "bunx" "$@"; }
      pip() { wrapSafeChainCommand "pip" "$@"; }
      pip3() { wrapSafeChainCommand "pip3" "$@"; }
      uv() { wrapSafeChainCommand "uv" "$@"; }
      uvx() { wrapSafeChainCommand "uvx" "$@"; }
      poetry() { wrapSafeChainCommand "poetry" "$@"; }
      python() { wrapSafeChainCommand "python" "$@"; }
      python3() { wrapSafeChainCommand "python3" "$@"; }
      pipx() { wrapSafeChainCommand "pipx" "$@"; }

      npm() {
        if [[ "$1" == "-v" || "$1" == "--version" ]] && [[ $# -eq 1 ]]; then
          command npm "$@"
          return
        fi

        wrapSafeChainCommand "npm" "$@"
      }
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
      core.hooksPath = "${git-hooks}";
    };
  };

  # 設定ファイル
  xdg.configFile."starship.toml".source = ./config/starship.toml;
  xdg.configFile."karabiner/karabiner.json" = {
    source = ./config/karabiner/karabiner.json;
    force = true;
  };
  xdg.configFile."wezterm/wezterm.lua".source = ./config/wezterm/wezterm.lua;
  xdg.configFile."wezterm/keybinds.lua".source = ./config/wezterm/keybinds.lua;
  home.file."Library/Application Support/com.mitchellh.ghostty/config.ghostty".source =
    ./config/ghostty/config.ghostty;
}
