# GitHub App PR Workflow

Use a GitHub App installation for repository automation when possible. It gives
agents scoped, revocable access without storing a personal access token.

## Credential Model

Record only metadata in durable notes:

- app purpose;
- owner;
- installed repositories;
- helper paths or secret storage paths;
- requested permission set;
- revocation and rotation steps.

Do not record private keys, installation tokens, personal access tokens, or
plaintext credential values.

## Preferred Tool Split

- Use `git` for local repository state, branches, commits, diffs, and history.
- Use authenticated `git fetch` and `git push` with a short-lived app token or
  askpass helper.
- Use `gh` or another GitHub API client for PR metadata, review comments,
  checks, rulesets, and issue comments.
- Request broad app permissions only when a command actually needs them.

## PR Flow

1. Clone or update the repo.
2. Inspect branch protection or repository rules.
3. Create a focused feature branch.
4. Make scoped commits.
5. Run validation relevant to the change.
6. Push the branch with a short-lived app token.
7. Open a pull request against the protected base branch.
8. Link the PR back to the tracking issue.
9. Respond to review comments individually when practical.

## Workflow-File Pushes

Creating or changing a file under `.github/workflows/` requires a GitHub App
installation token with the separate `workflows:write` permission. Keep the
token repository-restricted and request only the normal PR permissions plus
that additional permission.

`CODEX_GH_PERMISSIONS_JSON` and `CODEX_GH_REPO` are wrapper inputs, not Git
settings. `codex-gh` forwards them for CLI and API operations. An older stock
`codex-github-askpass` that invokes `codex-github-token` without arguments does
not currently forward either value, so setting them around `git push` has no
effect on the token it mints. Inspect or reinstall the current helper from the
[Codex Agent Setup repository](https://github.com/TheWorstProgrammerEver/Codex-Agent-Setup/tree/main/github)
before relying on this path. The current source-controlled askpass helper
forwards both values; the default path remains unchanged when they are unset.

First verify that the App can mint the narrow repository token. Request only an
expiry timestamp so the token value is never printed:

```bash
codex-github-token \
  --repo OWNER/REPO \
  --permissions-json '{"contents":"write","pull_requests":"write","workflows":"write"}' \
  --expires-at
```

Then exercise the exact branch ref with an authenticated dry run:

```bash
CODEX_GH_REPO=OWNER/REPO \
CODEX_GH_PERMISSIONS_JSON='{"contents":"write","pull_requests":"write","workflows":"write"}' \
GIT_TERMINAL_PROMPT=0 \
GIT_ASKPASS="$(command -v codex-github-askpass)" \
  git push --dry-run origin HEAD:refs/heads/BRANCH
```

After the dry run succeeds, repeat the command without `--dry-run` to push the
branch. Keep the overrides scoped to these commands. Do not put the token in a
shell variable, command argument, remote URL, log, or temporary credential
file. Ordinary branches without workflow changes should continue through the
default askpass path without the two override variables.

## Empty Repository Bootstrap

A pull request needs an existing base branch. If a repo has no commits and no
default branch, create the smallest possible base branch first, such as an empty
initial commit on `main`, then put real content on a feature branch and open the
PR normally.

Document that bootstrap action in the PR or issue because it is the only direct
base-branch push in the flow.

## Review And Ruleset Checks

Before claiming a PR is ready:

- check mergeability and ruleset requirements;
- confirm approval requirements and last-push approval behavior;
- inspect unresolved review threads;
- check required status checks or explain when none exist;
- avoid deleting branches until the PR is merged and branch cleanup is safe.

## Pinned Review Worktrees

An ordinary branch checkout is sufficient when the local checkout is clean,
already on the PR branch being reviewed, and owned by the current reviewer for
the whole validation window.

Use a detached temporary worktree when the main checkout is shared, dirty, on a
different branch, used by scheduled workers, or likely to be touched by another
agent during review. Pin the worktree to the PR head SHA when available; pin to
the reviewed remote branch when the exact SHA is not available yet.

```bash
git fetch origin
git worktree add --detach <review-worktree> <pr-head-sha>
```

If the exact head SHA is not available:

```bash
git fetch origin <pr-branch>
git worktree add --detach <review-worktree> origin/<pr-branch>
```

Run inspection, diffs, builds, and tests from the pinned worktree, and record
the reviewed SHA or remote branch in the review notes. This keeps validation
scoped to the submitted artifact even if another agent later moves the shared
checkout or pushes a stacked follow-up branch.

Before cleanup, copy or summarize only the review artifacts that need to be
preserved. Then remove the temporary worktree:

```bash
git worktree remove <review-worktree>
git worktree prune
```

## Gotchas

- Failed token minting can leave empty shell variables and cause confusing
  authentication errors.
- PRs can be Git-mergeable while still ruleset-blocked.
- Combined commit status may show pending when no checks exist; inspect the PR
  and ruleset directly when in doubt.
