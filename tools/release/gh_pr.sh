#!/bin/zsh
# gh.sh pr <head> <title> <body>  -> prints PR number + url
# gh.sh merge <number> <title>     -> merge commit, deletes head branch
GITHUB_TOKEN=$(zsh -ic 'printf "%s" "$GITHUB_TOKEN"' 2>/dev/null | grep -aoE 'github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9]+' | tail -1)
API=https://api.github.com/repos/nathantau/arena-brawler
H=(-sS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
case $1 in
pr)
  jq -n --arg h "$2" --arg t "$3" --arg b "$4" '{head:$h, base:"main", title:$t, body:$b}' \
    | curl $H -X POST $API/pulls -d @- | jq -r '"\(.number) \(.html_url) \(.message // "")"' ;;
merge)
  head=$(curl $H $API/pulls/$2 | jq -r .head.ref)
  jq -n --arg t "$3" '{merge_method:"merge", commit_title:$t}' \
    | curl $H -X PUT $API/pulls/$2/merge -d @- | jq -r '"\(.merged) \(.sha // "") \(.message // "")"'
  curl $H -X DELETE $API/git/refs/heads/$head -o /dev/null -w "branch delete: %{http_code}\n" ;;
esac
