# watch-prs で落ち着いた PR のうち、失敗した検査が無く、レビューで直すものが無いと言われたものを
# マージコミットでマージする。それ以外はマージせずに理由を出す。
#   merge-when-green [-n] [-l ラベル] [-t 分] [-r レビューの検査名] PR ...
#   -t, -r は watch-prs にそのまま渡す(-r は空にできない)。
#   レビューの検査が SUCCESS なだけでは足りない(指摘を残しても SUCCESS で終わる)。
#   直すものが無いときにレビューが付けるラベル(既定「マージ予約」)も要る。
#   -n  レビューの検査が無い PR(review=-)もマージする。無いときはラベルも見ない。
#   -l  直すものが無いことを表すラベルの名前(空にはできない)
allow_no_review=0
label="マージ予約"
pass=()
while getopts nl:t:r: opt; do
  case "$opt" in
    n) allow_no_review=1 ;;
    l)
      # 空にするとラベルの無い PR が照らし合わせを素通りするので受け付けない
      [ -n "$OPTARG" ] || { echo "merge-when-green では -l を空にできない" >&2; exit 2; }
      label=$OPTARG ;;
    t) pass+=(-t "$OPTARG") ;;
    r)
      # 空にするとレビューを見なくなり、指摘があってもマージできてしまうので受け付けない
      [ -n "$OPTARG" ] || { echo "merge-when-green では -r を空にできない" >&2; exit 2; }
      pass+=(-r "$OPTARG") ;;
    *) echo "使い方: merge-when-green [-n] [-l ラベル] [-t 分] [-r 検査名] PR ..." >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

watch-prs "${pass[@]}" "$@" | while IFS= read -r line; do
  case "$line" in
    "ALL DONE"* | *TIMEOUT*) echo "$line"; continue ;;
  esac
  s=${line%% *}
  why=""
  if [[ "$line" != *" OPEN "* ]]; then
    why="開いていない"
  elif [[ "$line" != *"fail=[]"* ]]; then
    why="落ちた検査がある"
  elif [[ "$line" == *"review=-"* ]]; then
    [ "$allow_no_review" = 1 ] || why="レビューの検査が無い(無くてよいなら -n)"
  elif [[ "$line" != *"review=SUCCESS"* ]]; then
    why="レビューの検査が通っていない"
  elif labels=${line#*labels=[}; labels=${labels%%]*}; [[ ",$labels," != *",$label,"* ]]; then
    why="レビューに指摘がある(「${label}」が付いていない)"
  fi
  if [ -n "$why" ]; then
    echo "$s マージしない:$why:${line#* }"
  elif out=$(gh pr merge "${s#*#}" -R "${s%#*}" --merge 2>&1); then
    echo "$s マージした"
  else
    echo "$s マージできなかった:$(tail -1 <<<"$out")"
  fi
done
