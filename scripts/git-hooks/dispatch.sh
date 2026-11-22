# core.hooksPath に置く、すべてのリポジトリに共通のフック。フックの名前ごとにこのスクリプトが呼ばれる。
# 共通の処理(いまは pre-push の共通の静的ルール)を流したあと、リポジトリ自身の .git/hooks/<名前> があれば
# 同じ引数と標準入力で続けて呼ぶ。core.hooksPath を設定すると .git/hooks は読まれなくなるため。
# リポジトリが自分で core.hooksPath を設定している(husky など)ときは、そちらが優先され、これは呼ばれない。
name=$(basename "$0")

stdin_file=""
if [ "$name" = pre-push ]; then
  # pre-push は push する参照を標準入力で受け取る。リポジトリのフックにも同じものを渡す。
  stdin_file=$(mktemp)
  trap 'rm -f "$stdin_file"' EXIT
  cat > "$stdin_file"
  static-rules-pre-push
fi

own="$(git rev-parse --git-common-dir)/hooks/$name"
if [ -x "$own" ]; then
  if [ -n "$stdin_file" ]; then
    "$own" "$@" < "$stdin_file"
  else
    "$own" "$@"
  fi
fi
