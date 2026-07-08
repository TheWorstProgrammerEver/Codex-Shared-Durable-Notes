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
- Unattended API keys are dedicated, revocable, stored outside git, and not
  temporary validation keys.
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

## Credentials

- Use a dedicated Linear API key for unattended pollers.
- Store it only in ignored local configuration or a protected service
  environment file.
- Do not store it in git, durable notes, comments, logs, or issue descriptions.
- Use Linear MCP OAuth for interactive sessions, and complete OAuth as a
  post-boot operator step on fresh hosts.
