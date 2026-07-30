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

## Authorization Evidence

Keep configuration and authorization checks separate. A successful check in
one path does not prove that another path can write:

- Minting a token expiry timestamp with the requested permissions proves that
  the helper and App configuration can mint that token. It does not prove
  repository selection or any write operation.
- Listing the installation repositories proves that the installation includes
  the selected repository. It does not prove the token's write scope or either
  write transport.
- Running `git push --dry-run` for the exact refspec proves that the Git
  command, remote, source, destination, and negotiation are usable without
  applying the ref update. It does not prove authorization for a real Git ref
  update.
- Pushing the real issue branch proves that Git HTTPS transport can create or
  update that branch. It does not prove Git Database REST API write access.
- Creating and deleting a ref through the Git Database REST API proves those
  exact API writes. It does not prove Git HTTPS transport authorization.

Treat `git push --dry-run` as a command and refspec preflight, not as write
authorization evidence. A server can allow the dry run while rejecting the
real ref update.

Prefer the real issue-branch push as the narrowest useful Git transport check:

```bash
GIT_TERMINAL_PROMPT=0 \
GIT_ASKPASS="$(command -v codex-github-askpass)" \
  git push origin HEAD:refs/heads/ISSUE-BRANCH
```

If a separate API write probe is necessary, create one explicitly named
disposable branch from the base branch's current commit, then remove it
immediately. Use a unique `ISSUE-UTCSTAMP` suffix, record the exact generated
name until cleanup succeeds, and never target the primary branch itself:

```bash
probe_ref="codex-write-probe-ISSUE-UTCSTAMP"
probe_base_sha="$(
  CODEX_GH_REPO=OWNER/REPO \
  CODEX_GH_PERMISSIONS_JSON='{"contents":"write"}' \
    codex-gh api repos/OWNER/REPO/git/ref/heads/BASE --jq .object.sha
)"

CODEX_GH_REPO=OWNER/REPO \
CODEX_GH_PERMISSIONS_JSON='{"contents":"write"}' \
  codex-gh api --silent -X POST repos/OWNER/REPO/git/refs \
  -f ref="refs/heads/${probe_ref}" \
  -f sha="${probe_base_sha}"

CODEX_GH_REPO=OWNER/REPO \
CODEX_GH_PERMISSIONS_JSON='{"contents":"write"}' \
  codex-gh api --silent -X DELETE \
  "repos/OWNER/REPO/git/refs/heads/${probe_ref}"
```

If creation succeeds but cleanup fails, stop and retry the exact delete before
continuing. Do not broaden cleanup to a prefix or wildcard. Keep token values
out of variables, command arguments, remote URLs, logs, and temporary
credential files. This probe demonstrates API ref-write authorization only; it
is not a fallback proof that Git HTTPS push is authorized.

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

Then preflight the exact branch ref with an authenticated dry run:

```bash
CODEX_GH_REPO=OWNER/REPO \
CODEX_GH_PERMISSIONS_JSON='{"contents":"write","pull_requests":"write","workflows":"write"}' \
GIT_TERMINAL_PROMPT=0 \
GIT_ASKPASS="$(command -v codex-github-askpass)" \
  git push --dry-run origin HEAD:refs/heads/BRANCH
```

Dry-run success validates the command and refspec but does not prove that
GitHub will authorize the write. Repeat the command without `--dry-run` to
perform the conclusive Git transport check by pushing the issue branch. Keep
the overrides scoped to these commands. Do not put the token in a shell
variable, command argument, remote URL, log, or temporary credential file.
Ordinary branches without workflow changes should continue through the default
askpass path without the two override variables.

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
- A successful `git push --dry-run` can be followed by a `403` on the real
  update; diagnose token scope, repository selection, Git transport, and API
  ref writes as separate boundaries.
- PRs can be Git-mergeable while still ruleset-blocked.
- Combined commit status may show pending when no checks exist; inspect the PR
  and ruleset directly when in doubt.
