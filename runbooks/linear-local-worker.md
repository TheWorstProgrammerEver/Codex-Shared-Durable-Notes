# Linear Local Worker Model

Use Linear as the canonical backlog, comment history, status surface, and human
review queue while keeping execution on a durable local agent host.

## Operating Model

- Linear owns issues, statuses, labels, comments, priorities, and review.
- The local host owns execution, local files, shell access, services, timers,
  durable notes, and recovery.
- Scheduled polling should avoid spending model tokens while idle.
- A local delegator can use the Linear API to claim exactly one eligible issue,
  then spawn Codex only after a successful claim.
- Interactive Codex sessions can use Linear MCP/plugin tools for reading and
  updating issues.

## Suggested Statuses

- `Backlog`: work exists but is not ready for automatic pickup.
- `Waiting For Agent`: reviewed and ready for local worker claim.
- `Agent In Progress`: claimed and running.
- `Blocked`: agent cannot proceed without human or external input.
- `In Review`: agent believes the work is complete and needs review.
- `Done`: human or process accepted the result.

New issues should default to backlog unless the operator explicitly approves
immediate agent pickup.

## Suggested Labels

Use labels to communicate worker eligibility and execution preferences:

- an agent-specific label for a named host or worker;
- an `agent:any` style label when any compatible worker may claim it;
- model labels for intended Codex model selection;
- reasoning-effort labels when the worker supports them.

Keep model labels separate from reasoning labels so scheduling decisions remain
easy to parse.

## Project Handoff Preflight

Before moving a project-sized batch of issues into an automatic pickup status,
confirm the operational wiring as well as the issue content:

- Ready issues use the worker's configured eligible status and have at least
  one configured agent label.
- Blocking dependency relations are encoded in Linear, and the active worker
  version skips issues whose blockers are not complete.
- The target repository is installed for the GitHub App, has a local checkout
  or an explicit repository link in issue context, and accepts an authenticated
  dry-run push.
- The worker service or timer is running from the intended stable branch and
  build, not a review branch or experimental checkout.
- Completion and review status names in repository guidance match the worker's
  configured completion, review, and blocked statuses.
- Unattended workers that need distinct attribution use a dedicated Linear app
  user with narrow scopes and team grants. Its credentials are revocable,
  stored outside git, and not temporary validation credentials.
- The first claimed issue can perform required local or LAN validation before
  downstream issues are bulk-enabled.

## Claim Discipline

A local worker should:

1. acquire a local claim lock;
2. check whether the host is already busy;
3. query eligible Linear issues;
4. claim one issue atomically by status transition and claim comment;
5. release the claim lock;
6. spawn Codex with the issue snapshot;
7. write logs and local run state;
8. report completion, blocker, or failure back to Linear.

For multi-hour transfers, imports, backups, migrations, or builds, the spawned
agent should hand the work to an inspectable durable runner such as systemd or
tmux and leave state/log paths in Linear before yielding. For Kiwix/ZIM
downloads specifically, follow the detached `aria2c` guidance in
`runbooks/offline-knowledge-reservoir.md`.

## Codex Execution Authentication Recovery

Treat the worker's two authentication boundaries independently:

- Linear API authentication lets the poller read, claim, comment on, and change
  issues.
- OpenAI Codex execution authentication lets the spawned `codex exec` process
  start an agent session.

A healthy timer, a successful Linear claim, or `codex login status` does not
prove that a non-interactive Codex process can authenticate in the service
environment. Before requeueing work after an authentication incident:

1. Stop automatic claims while preserving evidence. Stop the timer, but do not
   kill an active service or Codex child solely because another launch failed.
2. Inspect the service and timer status, service main PID, and recent journal.
   Resolve the configured service user, working directory, environment-file
   path, Codex binary, Codex working directory, and state directory without
   printing environment-file contents.
3. Inspect `current.json`, then verify its PID with `ps` or `kill -0`. Treat a
   live matching process as active work and leave both its local state and
   Linear issue unchanged. If local state is absent or stale, inspect the
   per-issue log and process table before changing the issue.
4. Run `codex login status` as the service user for orientation, then run a
   tiny, non-interactive `codex exec` smoke test through the same systemd user,
   working directory, environment file, Codex binary, and Codex working
   directory. Use a non-mutating sandbox and a prompt such as “Reply with
   exactly OK.” Do not claim or requeue issues until this succeeds.
5. Classify every stranded claim from its own log and state evidence. Requeue
   only when the log proves the Codex session failed during authentication
   before any tool activity or repository/external mutation. Add an
   identity-attributed Linear comment that records the reason and recovery
   action.
6. If the log is missing, ambiguous, or shows any agent/tool activity, do not
   requeue automatically. Leave the issue in its current active state while a
   live process exists; otherwise move it to `Blocked` for operator review.
7. Restart the timer only after the smoke test succeeds and all stale claims
   have been classified. Do not disturb active current-state workers that
   survived the incident.

Useful read-only inspection commands, with deployment-specific unit and path
values substituted, include:

```bash
systemctl status <worker.service> <worker.timer> --no-pager
systemctl show <worker.service> \
  --property=ActiveState,SubState,MainPID,User,WorkingDirectory,EnvironmentFiles,ExecStart
journalctl -u <worker.service> --since <incident-start> --no-pager
sed -n '1,160p' <state-directory>/current.json
ps -fp <current-json-pid>
tail -n 200 <per-issue-log>
```

For a system service, a transient unit can reproduce the relevant execution
context without exposing credential values:

```bash
sudo -u <service-user> <codex-bin> login status
sudo systemd-run --wait --pipe --collect \
  --unit=codex-exec-auth-smoke \
  --uid=<service-user> \
  --working-directory=<codex-working-directory> \
  --property=EnvironmentFile=<worker-environment-file> \
  <codex-bin> exec --skip-git-repo-check --sandbox read-only \
  "Reply with exactly OK."
```

Adapt the smoke command to the installed Codex CLI and unit type. If the worker
is a user service, use its user-manager context instead of a system transient
unit. The important validation is the real non-interactive execution path, not
the exact command spelling.

## Credentials

- Follow `runbooks/linear-agent-identity.md` when a worker needs its own visible
  identity. Prefer one private OAuth app and app user per durable agent over a
  personal API key or user-authorized OAuth session.
- Use client-credentials app tokens for unattended pollers. Mint or renew the
  30-day token on startup and after a `401`; store the client secret only in a
  protected local secret store or service credential facility.
- Use the same app OAuth bearer-token identity for GraphQL and MCP when the MCP
  client supports direct bearer-token authentication. Otherwise treat
  interactive user OAuth as a separately attributed fallback.
- Store no client secret, access token, refresh token, or personal API key in
  git, durable notes, comments, logs, issue descriptions, or reusable images.
- A personal API key is a time-bounded fallback for a workflow intentionally
  acting as its human owner; it is not a distinct agent identity.

## Related Work

- [RYA-173 - Document and harden Linear worker recovery for Codex exec auth failures](https://linear.app/ryan-hayward/issue/RYA-173/document-and-harden-linear-worker-recovery-for-codex-exec-auth)
- [RYA-213 - Harden Linear delegator recovery for immediate Codex exec auth failures](https://linear.app/ryan-hayward/issue/RYA-213/harden-linear-delegator-recovery-for-immediate-codex-exec-auth)
- [Linear Agent Identity](linear-agent-identity.md)
