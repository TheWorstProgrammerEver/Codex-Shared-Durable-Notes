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

## Credentials

- Use a dedicated Linear API key for unattended pollers.
- Store it only in ignored local configuration or a protected service
  environment file.
- Do not store it in git, durable notes, comments, logs, or issue descriptions.
- Use Linear MCP OAuth for interactive sessions, and complete OAuth as a
  post-boot operator step on fresh hosts.
