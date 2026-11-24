# core.hooksPath に置く、すべてのリポジトリに共通のフック。フックの名前ごとにこのスクリプトが呼ばれる。
# core.hooksPath を設定すると .git/hooks は読まれなくなるので、共通の処理のあと、リポジトリ自身の
# hooks/<名前> があれば同じ引数と標準入力で続けて呼ぶ。
#
# 共通の処理:
# - pre-push:共通の静的ルール(static-rules-pre-push)。
# - Git LFS を使うリポジトリ(.gitattributes に filter=lfs がある)では、git-lfs が .git/hooks に入れる
#   はずだったフック(pre-push・post-checkout・post-commit・post-merge)を呼ぶ。core.hooksPath が
#   読み取り専用の場所を向くため、git lfs install はフックを入れられない。リポジトリ自身のフックが
#   すでに git lfs を呼んでいるときは、二重に呼ばない。
#
# リポジトリが自分で core.hooksPath を設定しているとき(husky、pre-commit など)は、そちらが優先され、
# これは呼ばれない。
name=$(basename "$0")
# git init と git clone は、.git に HEAD を書く前(HEAD.lock しか無いとき)に reference-transaction を呼ぶ。
# そのときは rev-parse がリポジトリと認めず失敗するので、リポジトリ自身のフックは無いものとして続ける。
# (できたばかりの .git/hooks には *.sample しか無く、呼ぶものは無い)
own=""
if common=$(git rev-parse --git-common-dir 2> /dev/null); then
  own="$common/hooks/$name"
fi

stdin_file=""
if [ "$name" = pre-push ]; then
  # pre-push は push する参照を標準入力で受け取る。共通の処理とリポジトリのフックの全部に同じものを渡す。
  stdin_file=$(mktemp)
  trap 'rm -f "$stdin_file"' EXIT
  cat > "$stdin_file"
  static-rules-pre-push < "$stdin_file"
fi

case "$name" in
  pre-push | post-checkout | post-commit | post-merge)
    # Read into a variable first: with pipefail, grep -q closing the pipe early fails git show.
    attributes=$(git show HEAD:.gitattributes 2>/dev/null || true)
    if command -v git-lfs > /dev/null &&
      ! { [ -f "$own" ] && grep -q 'git lfs' "$own"; } &&
      grep -q 'filter=lfs' <<< "$attributes"; then
      if [ -n "$stdin_file" ]; then
        git lfs "$name" "$@" < "$stdin_file"
      else
        git lfs "$name" "$@"
      fi
    fi
    ;;
esac

if [ -x "$own" ]; then
  if [ -n "$stdin_file" ]; then
    "$own" "$@" < "$stdin_file"
  else
    exec "$own" "$@"
  fi
fi
