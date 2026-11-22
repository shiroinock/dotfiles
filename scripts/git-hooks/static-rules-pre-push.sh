# push の前に、shiroinock/workflows の共通の静的ルール(ast-grep)を流す。
# CI の static-rules.yml を置いているリポジトリだけが対象。CI は検査するだけで直さないので、ここで直す。
#
# - 作業ツリーがきれいなら、直せるものを直して push を止める(差分を確かめてコミットし、push し直す)。
# - 作業ツリーに変更があるなら、直さずに引っかかった場所を出して push を止める。
# - ルールを取ってこられない(オフラインなど)ときは、警告を出して push は止めない。CI が見つける。
# SKIP_STATIC_RULES=1 で飛ばせる(git push --no-verify はほかのフックも飛ばす)。
# STATIC_RULES_FLAKE でルールの取り先を替えられる(既定は CI と同じ main)。
top=$(git rev-parse --show-toplevel)
[ -f "$top/.github/workflows/static-rules.yml" ] || exit 0
if [ "${SKIP_STATIC_RULES:-}" = 1 ]; then
  echo "共通の静的ルール:SKIP_STATIC_RULES=1 なので飛ばす" >&2
  exit 0
fi
cd "$top" || exit 1

if ! out=$(nix build "${STATIC_RULES_FLAKE:-github:shiroinock/workflows}#rules" --no-link --print-out-paths 2>/dev/null); then
  echo "共通の静的ルール:ルールを取ってこられなかったので、確かめずに push する(CI が確かめる)" >&2
  exit 0
fi
rules="$out/bin/rules"

if "$rules" --report-style short > /dev/null 2>&1; then
  exit 0
fi

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  "$rules" --report-style short >&2 || true
  echo "共通の静的ルールに引っかかった。作業ツリーに変更があるので直していない。" >&2
  echo "変更を片付けてから \`nix run github:shiroinock/workflows#rules -- --fix\` で直し、コミットして push し直す。" >&2
  exit 1
fi

"$rules" --fix > /dev/null 2>&1 || true
changed=$(git status --porcelain --untracked-files=no)
if "$rules" --report-style short > /dev/null 2>&1; then
  echo "共通の静的ルールに引っかかったので直した。差分を確かめてコミットし、push し直す:" >&2
  echo "$changed" >&2
  exit 1
fi
"$rules" --report-style short >&2 || true
if [ -n "$changed" ]; then
  echo "共通の静的ルールで直せるものは直したが、手で直すものが残っている(上を見る)。直したファイル:" >&2
  echo "$changed" >&2
else
  echo "共通の静的ルールに引っかかった。自動では直せないので、上の場所を手で直す。" >&2
fi
exit 1
