# PR の検査を見張り、落ち着いた PR から1行ずつ出す。全部落ち着くか、期限で終わる。
#   watch-prs [-t 分] [-r レビューの検査名] PR ...
#   PR は repo#num(持ち主は gh でログイン中のユーザー)、owner/repo#num、PR の URL のどれか。
#   -t  期限(既定 15 分)
#   -r  review= に出す検査の名前(既定 "review / review"、空にすると見ない)
# 落ち着いた = マージ・クローズされた、または 90 秒たって検査が1つ以上あり、どれも走っていない。
# 検査が1つも無い PR は、3 分たっても無ければ落ち着いたとみなす。
# 出力:  owner/repo#num STATE review=… fail=[…] labels=[…] auto=…   最後に ALL DONE か TIMEOUT
limit=15
review="review / review"
while getopts t:r: opt; do
  case "$opt" in
    t) limit=$OPTARG ;;
    r) review=$OPTARG ;;
    *) echo "使い方: watch-prs [-t 分] [-r 検査名] PR ..." >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || { echo "使い方: watch-prs [-t 分] [-r 検査名] PR ..." >&2; exit 2; }

owner=""
prs=()
for a in "$@"; do
  case "$a" in
    https://github.com/*/pull/*)
      p=${a#https://github.com/}; n=${p#*/pull/}; n=${n%%[/?#]*}
      prs+=("${p%%/pull/*}#$n") ;;
    */*'#'*) prs+=("$a") ;;
    *'#'*)
      [ -n "$owner" ] || owner=$(gh api user --jq .login)
      prs+=("$owner/$a") ;;
    *) echo "PR の形が分からない:$a" >&2; exit 2 ;;
  esac
done

start=$(date +%s)
declare -A settled
while :; do
  el=$(( $(date +%s) - start ))
  left=0
  for s in "${prs[@]}"; do
    if [ -n "${settled[$s]:-}" ]; then continue; fi
    if ! j=$(gh pr view "${s#*#}" -R "${s%#*}" --json state,labels,autoMergeRequest,statusCheckRollup 2>/dev/null); then
      left=1; continue
    fi
    # 検査は2種類ある。CheckRun(Actions など:status と conclusion)と、
    # StatusContext(commit status:名前は context、結果は state)。
    # 走っている = CheckRun は COMPLETED でないもの、StatusContext は PENDING / EXPECTED。
    # 失敗 = 通ったと言える結論(SUCCESS / NEUTRAL / SKIPPED)と、concurrency で取り消された
    # CANCELLED 以外。STARTUP_FAILURE や STALE も失敗に数える。
    line=$(jq -r --argjson el "$el" --arg rname "$review" '
      (.statusCheckRollup // [] | map(. + {name: (.name // .context)})) as $c
      | ($c | map(select(if .__typename == "StatusContext"
                         then (.state == "PENDING" or .state == "EXPECTED")
                         else .status != "COMPLETED" end))) as $run
      | ($c | map(select(if .__typename == "StatusContext"
                         then (.state == "FAILURE" or .state == "ERROR")
                         else (.status == "COMPLETED" and ((.conclusion // "") as $x
                               | ($x == "SUCCESS" or $x == "NEUTRAL" or $x == "SKIPPED" or $x == "CANCELLED") | not)) end)
                  | .name)) as $bad
      | (if $rname == "" then "-" else ($c | map(select(.name == $rname)) | map(.conclusion // .state) | first // "-") end) as $rv
      | if .state != "OPEN" or ($el >= 90 and ($c|length) > 0 and ($run|length) == 0) or (($c|length) == 0 and $el >= 180)
        then "\(.state) review=\($rv) fail=[\($bad|join(","))] labels=[\([.labels[].name]|join(","))] auto=\(.autoMergeRequest != null)"
        else empty end' <<<"$j")
    if [ -n "$line" ]; then settled[$s]=1; echo "$s $line"; else left=1; fi
  done
  if [ "$left" = 0 ]; then echo "ALL DONE ($(( el / 60 )) 分)"; exit 0; fi
  if [ "$el" -ge $(( limit * 60 )) ]; then
    for s in "${prs[@]}"; do
      if [ -z "${settled[$s]:-}" ]; then echo "$s TIMEOUT(まだ検査が走っている)"; fi
    done
    exit 0
  fi
  sleep 30
done
