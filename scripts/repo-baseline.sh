# 自分の GitHub リポジトリに共通の設定(ベースライン)を入れる。何度実行してもよい。
#   使い方: repo-baseline            # フォークとアーカイブを除く全リポジトリ
#           repo-baseline repo1 repo2  # 指定したリポジトリだけ
#
# 入れる設定:
#   - マージ方法はマージコミットのみ(スカッシュとリベースは無効)
#   - 自動マージを許可、マージ後にブランチを自動削除、「Update branch」ボタンを出す
#   - シークレットスキャンと push protection(使えないプランでは飛ばす)
#   - Dependabot の脆弱性アラートをオン。自動の修正 PR はオフ(修正の PR は Renovate が出す)
#   - ルールセット「main を守る」: デフォルトブランチの削除と force push を禁止し、PR を必須にする
#     (承認は 0 人、マージコミットのみ)。同名のルールセットが既にあれば触らない。
set +e  # 失敗は1件ずつ報告して先へ進む

OWNER="${OWNER:-shiroinock}"
RULESET_NAME="main を守る"

if [ "$#" -gt 0 ]; then
  repos=("$@")
else
  mapfile -t repos < <(gh repo list "$OWNER" --limit 1000 --json name,isFork,isArchived \
    --jq '.[] | select(.isFork|not) | select(.isArchived|not) | .name')
fi

ruleset_body=$(cat <<JSON
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge"]
    } }
  ]
}
JSON
)

for repo in "${repos[@]}"; do
  full="$OWNER/$repo"
  printf '== %s\n' "$full"

  if gh api -X PATCH "repos/$full" --silent \
      -F allow_merge_commit=true -F allow_squash_merge=false -F allow_rebase_merge=false \
      -F allow_auto_merge=true -F delete_branch_on_merge=true -F allow_update_branch=true; then
    echo "   マージ設定: OK"
  else
    echo "   マージ設定: 失敗"
  fi

  if gh api -X PATCH "repos/$full" --silent --input - 2>/dev/null <<'JSON'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
JSON
  then
    ss=$(gh api "repos/$full" --jq '.security_and_analysis.secret_scanning.status // "unavailable"')
    echo "   シークレットスキャン: $ss"
  else
    echo "   シークレットスキャン: このプランでは使えない"
  fi

  if gh api -X PUT "repos/$full/vulnerability-alerts" --silent 2>/dev/null; then
    gh api -X DELETE "repos/$full/automated-security-fixes" --silent 2>/dev/null
    echo "   Dependabot アラート: オン(自動の修正 PR はオフ)"
  else
    echo "   Dependabot アラート: 失敗"
  fi

  existing=$(gh api "repos/$full/rulesets" --jq ".[] | select(.name==\"$RULESET_NAME\") | .id" 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "   ルールセット: 既にある(id $existing)ので触らない"
  elif out=$(gh api -X POST "repos/$full/rulesets" --input - <<<"$ruleset_body" 2>&1); then
    echo "   ルールセット: 作成"
  else
    echo "   ルールセット: 失敗 — $(printf '%s' "$out" | tail -1)"
  fi
done
