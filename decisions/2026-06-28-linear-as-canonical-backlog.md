# Use Linear As Canonical Backlog For Local Agents

Date: 2026-06-28

## Decision

Use Linear as the canonical backlog, discussion, status, and triage system for
Codex-managed local-agent work while keeping execution on durable local hosts.

## Rationale

- Linear already provides mature issues, comments, notifications, projects,
  teams, labels, statuses, and review workflows.
- Linear MCP gives interactive Codex sessions access to issue context and
  comments.
- A local worker can poll Linear cheaply, claim work, and spawn Codex only when
  work is ready.
- Keeping execution local preserves access to inspectable state, shell tools,
  tmux sessions, systemd services, and durable notes.

## Consequences

- Fresh-agent setup can preconfigure Linear MCP and plugin metadata, but must
  not bake OAuth tokens or API keys into images.
- Linear authentication remains a post-boot operator step.
- New work should start in backlog unless explicitly approved for immediate
  pickup.
- Local issue-claim automation should report completion, blocker, or failure
  back to Linear.
