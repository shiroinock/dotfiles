# watch-prs で落ち着いた PR のうち、失敗した検査が無く、レビューの検査が通ったものをマージコミットでマージする。
# それ以外はマージせずに理由を出す。引数は watch-prs と同じ。
#   merge-when-green [-t 分] [-r レビューの検査名] PR ...
#   -r '' にすると、レビューの検査を待たずに失敗が無いものをマージする。
need_review=1
prev=""
for a in "$@"; do
  if [ "$prev" = -r ] && [ -z "$a" ]; then need_review=0; fi
  prev=$a
done

watch-prs "$@" | while IFS= read -r line; do
  case "$line" in
    "ALL DONE"* | *TIMEOUT*) echo "$line"; continue ;;
  esac
  s=${line%% *}
  if [[ "$line" == *" OPEN "* && "$line" == *"fail=[]"* ]] && { [ "$need_review" = 0 ] || [[ "$line" == *"review=SUCCESS"* ]]; }; then
    if out=$(gh pr merge "${s#*#}" -R "${s%#*}" --merge 2>&1); then
      echo "$s マージした"
    else
      echo "$s マージできなかった:$(tail -1 <<<"$out")"
    fi
  else
    echo "$s マージしない:${line#* }"
  fi
done
