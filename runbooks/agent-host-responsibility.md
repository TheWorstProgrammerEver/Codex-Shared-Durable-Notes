# Agent Host Responsibility

Dedicated local agent hosts should be boring, inspectable, and recoverable.
Prefer plain files, systemd, SSH, tmux, git, and Markdown over opaque background
state.

## Principles

- Keep the host understandable from the filesystem and standard operating-system
  tools.
- Use durable notes for continuity across sessions.
- Keep root-level pointers such as `AGENTS.md`, `CODEX_TODO.md`, and
  `REMOTE_ACCESS.md` small and discoverable.
- Prefer systemd services and timers for recurring work.
- Use tmux or an equivalent persistent terminal for long-lived interactive
  sessions.
- Keep credentials scoped and revocable.
- Prefer GitHub Apps or similarly narrow app credentials over personal access
  tokens for repository automation.
- Avoid baking OAuth tokens, API keys, private SSH keys, or other secrets into
  images, repos, or shared durable notes.

## State Boundaries

Store local operational state under predictable local paths, and document only
metadata in durable notes:

- what the state is for;
- where it lives;
- which service owns it;
- how to stop, inspect, rotate, or delete it.

Do not turn inboxes, temp directories, logs, or one-off task outputs into
durable memory by accident. Promote only facts that will help future agents.

## Human Operator Access

For headless machines:

- document SSH host/user details in a local-only access note;
- preserve a tested attach command for the persistent agent session;
- disable password SSH after public-key access is confirmed, when policy allows;
- keep emergency recovery steps visible and current.

## Failure Bias

When automation fails, prefer recoverable partial progress:

- write status to a file or service log;
- leave clear next steps in durable notes;
- avoid destructive cleanup unless the operator asked for it;
- do not hide failure inside a long-running daemon.
