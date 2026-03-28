# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

nix-darwin + Home Manager による macOS (Apple Silicon) dotfiles管理リポジトリ。対象ホスト名は `MacBook-Air`、ユーザーは `shiroino`。

## Architecture

- **flake.nix** — エントリーポイント。nixpkgs-unstable / nix-darwin / home-manager を入力とし、`darwinConfigurations."MacBook-Air"` を定義
- **system.nix** — macOS システムレベル設定（Homebrew casks、PAM Touch ID、zsh有効化など）
- **home.nix** — Home Manager によるユーザー環境設定（パッケージ、zsh、git、starship、npm globalなど）
- **config/** — アプリ固有の設定ファイル（starship.toml など）。home.nix の `xdg.configFile` で配置される

## Commands

```bash
# システム全体をビルド・適用（switch）
darwin-rebuild switch --flake .

# ビルドのみ（適用しない）
darwin-rebuild build --flake .

# flake.lock の更新
nix flake update
```

## Key Details

- nixpkgs チャネルは **unstable** を使用
- Homebrew は GUI アプリ (casks) 専用。`onActivation.cleanup = "zap"` により、casks リストから外れたアプリは自動削除される
- zsh の `compinit` は Home Manager 側で `-u` 付きで実行し、system.nix 側では無効化している
- npm グローバルパッケージは `~/.npm-global` に配置（nix store が read-only のため）
