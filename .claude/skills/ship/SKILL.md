---
name: ship
description: Merge finished branches, test, push main and upload a TestFlight build of BrawlBits. Use when the user says "push", "merge and push", "ship it" or "release" — in this repo "push" ALWAYS includes the TestFlight build.
---

# Ship (merge → test → push → TestFlight)

"push" from the user = all of this, in one turn. Never force-push. Never read
`~/.appstoreconnect/private_keys/AuthKey_4TQNW332Q9.p8` (only check it exists; xcodebuild uses it).

## 0. Git identity
This machine may have no git identity, and you must not set git config. Export it in every shell that commits, merges or releases:
```
export GIT_AUTHOR_NAME="Nathan Au" GIT_AUTHOR_EMAIL=nathan@Nathans-Laptop.local GIT_COMMITTER_NAME="Nathan Au" GIT_COMMITTER_EMAIL=nathan@Nathans-Laptop.local
```
After a subagent finishes, check that `git config --local --get user.email` is empty. If it isn't, unset it.

## 1. PR per branch (no `gh` CLI, ever)
- `git push -q origin <branch>`
- `tools/release/gh_pr.sh pr <branch> "<title>" "<body>"` opens the PR through the GitHub API and needs `GITHUB_TOKEN` in the shell profile. If the token is missing, give the user the `https://github.com/nathantau/arena-brawler/pull/new/<branch>` link instead.
- End each PR body with the session's attribution footer.

## 2. Merge locally, then verify
- `git checkout main && git pull -q --ff-only`
- `git merge -q --no-ff -m "Merge pull request #N from nathantau/<branch>" -m "<title>" -m "<commit trailer>"`
- Conflicts are usually additive (tests, CLAUDE.md Status). Resolve them by keeping both sides.
- If art changed: `tools/sprites/.venv/bin/python tools/sprites/generate.py`, then `godot --path . --headless --import`. Afterwards restore the hand-tuned Flint files the generator overwrites: `git checkout -- assets/fx assets/sprites/flint_inferno.png`.
- Tests: these must pass before any push.
  - GUT: `godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Every test must pass.
  - Smoke test: see CLAUDE.md Commands. 0 `SCRIPT ERROR`, and the log ends with `smoke done <n> combos`.
- `git push -q origin main`
- Clean up each branch:
  - `git push origin --delete <b>`
  - `git worktree remove --force --force .claude/worktrees/agent-<id>`
  - `git branch -D <b>`

## 3. TestFlight (run in the background, identity exported)
```
ASC_KEY_ID=4TQNW332Q9 ASC_ISSUER_ID=96a7245c-300e-46d7-b2bc-1a795cfcfb2c tools/release/release_ios.sh > <log> 2>&1 && git push -q origin main
```
- The script commits the build-number bump only after the upload succeeds.
- If that commit fails (e.g. a missing identity), the upload has already happened. Commit `Bump iOS build to N` by hand. Don't re-run the script: Apple rejects a "Redundant Binary Upload".
- Report the build number to the user. If `LanDiscovery.VERSION` changed, also tell them every device must update.
- The release needs the ASC .p8 on this machine and Xcode signed in to team 7J8PR82Q2Z. Bundle ID `com.nabot.brawlbit` must never change.
