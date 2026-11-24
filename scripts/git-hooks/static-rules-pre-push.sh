# push の前に、shiroinock/workflows の共通の静的ルール(ast-grep)を、push するコミットに流す。
# CI で共通の静的ルールを流しているリポジトリ(.github/workflows に pinact.yml か static-rules.yml がある)
# だけが対象。静的ルールは pinact.yml のジョブで流れる(static-rules.yml は以前の置き場所)。CI は検査する
# だけで直さないので、ここで直す。
# 標準入力は pre-push と同じ(1行に `<local ref> <local sha> <remote ref> <remote sha>`)。
#
# - push するコミットごとに、そのコミットのファイルを一時ディレクトリに取り出して調べる。作業ツリーの
#   変更や追跡していないファイル、チェックアウトしていないブランチの中身に左右されない。
# - 消す push と、pinact.yml も static-rules.yml も含まないコミットは調べない。
# - 引っかかったコミットが HEAD で、追跡しているファイルに変更がなければ、直せるものを作業ツリーに直して
#   push を止める(差分を確かめてコミットし、push し直す)。それ以外は、引っかかった場所を出して止める。
# - ルールを取ってこられない(オフラインなど)ときは、警告を出して push は止めない。CI が見つける。
# SKIP_STATIC_RULES=1 で飛ばせる(git push --no-verify はほかのフックも飛ばす)。
# STATIC_RULES_FLAKE でルールの取り先を替えられる(既定は CI と同じ main)。
if [ "${SKIP_STATIC_RULES:-}" = 1 ]; then
  echo "共通の静的ルール:SKIP_STATIC_RULES=1 なので飛ばす" >&2
  exit 0
fi

# Commits to check: not deletions, with the workflow in them, each once.
targets=()
while read -r local_ref local_sha _remote_ref _remote_sha; do
  [ -n "${local_sha:-}" ] || continue
  [ -z "${local_sha//0/}" ] && continue # all zeros: a deletion
  git cat-file -e "$local_sha:.github/workflows/pinact.yml" 2>/dev/null ||
    git cat-file -e "$local_sha:.github/workflows/static-rules.yml" 2>/dev/null || continue
  case " ${targets[*]-} " in *" $local_sha:"*) continue ;; esac
  targets+=("$local_sha:$local_ref")
done
[ "${#targets[@]}" -gt 0 ] || exit 0

if ! out=$(nix build "${STATIC_RULES_FLAKE:-github:shiroinock/workflows}#rules" --no-link --print-out-paths 2>/dev/null); then
  echo "共通の静的ルール:ルールを取ってこられなかったので、確かめずに push する(CI が確かめる)" >&2
  exit 0
fi
rules="$out/bin/rules"

top=$(git rev-parse --show-toplevel 2>/dev/null || true)
head=$(git rev-parse --verify -q HEAD || true)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

failed=0
for t in "${targets[@]}"; do
  sha=${t%%:*}
  ref=${t#*:}
  dir="$tmp/$sha"
  mkdir -p "$dir/a"
  git archive "$sha" | tar -x -C "$dir/a"
  if (cd "$dir/a" && "$rules" --report-style short > /dev/null 2>&1); then
    continue
  fi
  failed=1

  # The checked-out commit with no changes to tracked files: fix it in the working tree.
  if [ -n "$top" ] && [ "$sha" = "$head" ] && git -C "$top" diff --quiet HEAD --; then
    cp -R "$dir/a" "$dir/b"
    (cd "$dir/b" && "$rules" --fix > /dev/null 2>&1) || true
    (cd "$dir" && diff -ruN a b > fix.patch) || true
    if [ -s "$dir/fix.patch" ] && git -C "$top" apply -p1 "$dir/fix.patch"; then
      echo "共通の静的ルール:$ref に引っかかったので、作業ツリーで直した。差分を確かめてコミットし、push し直す:" >&2
      git -C "$top" diff --stat >&2
      if ! (cd "$dir/b" && "$rules" --report-style short >&2); then
        echo "手で直すものも残っている(上を見る)。" >&2
      fi
      continue
    fi
  fi

  echo "共通の静的ルール:$ref($(git rev-parse --short "$sha"))に引っかかった:" >&2
  (cd "$dir/a" && "$rules" --report-style short >&2) || true
  if [ "$sha" = "$head" ]; then
    echo "追跡しているファイルに変更があるか、自動では直せないので、直していない。変更を片付けてから \`nix run github:shiroinock/workflows#rules -- --fix\` で直し、コミットして push し直す。" >&2
  else
    echo "チェックアウトしていないコミットなので、直していない。そのブランチで \`nix run github:shiroinock/workflows#rules -- --fix\` を流して直す。" >&2
  fi
done
exit "$failed"
