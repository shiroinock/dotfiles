---
name: rebuild
description: dotfiles の Nix ファイルや設定ファイルを編集した後に使用する。ビルド検証・適用・コミットまでを自動で行う。nix-darwin / Home Manager の変更を反映するときに自動で呼び出す。
---

dotfiles の変更を検証・適用・コミットする。以下のステップを順番に実行すること。

## 1. 未追跡ファイルのステージング

flake は git で追跡されていないファイルを参照できないため、新規作成したファイルを `git add` する。

```bash
git add <新規ファイル>
```

## 2. ビルド検証

switch する前に build で検証する。失敗したらエラーを報告して修正を提案し、このスキルの実行を中断する。

```bash
darwin-rebuild build --flake .
```

## 3. 適用

ビルドが成功した場合のみ switch を実行する。root 権限が必要。

```bash
sudo darwin-rebuild switch --flake .
```

switch が失敗した場合は `darwin-rebuild switch --rollback` でロールバックできることをユーザーに伝える。

## 4. 差分確認とコミット

`git diff` と `git status` で変更内容を表示し、ユーザーに確認を取ってからコミットする。
pre-commit hook (gitleaks, secretlint, statix, deadnix) が自動で走る。

hook が失敗した場合は修正してから新しいコミットを作成する。
