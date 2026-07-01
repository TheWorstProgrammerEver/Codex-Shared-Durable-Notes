# Shared Durable Notes Index

This index routes agents through reusable notes that can be merged into a local
Durable Notes skill hierarchy.

## Read First

- `README.md` - purpose, naming, dependency, and manual merge flow.
- `runbooks/durable-notes-memory-model.md` - wiki-plus-ledger memory model.
- `runbooks/agent-host-responsibility.md` - practical local-agent host posture.
- `credentials/NOTES.md` - credential metadata rules and examples.

## Runbooks

- `runbooks/github-app-pr-workflow.md` - GitHub App branch, PR, and review flow.
- `runbooks/linear-local-worker.md` - Linear as backlog with local execution.
- `runbooks/headless-operator-flows.md` - SSH, tmux, and OAuth handoff patterns.
- `runbooks/testing-cleanup-practices.md` - test isolation and cleanup checks.
- `runbooks/agent-email-identity.md` - dedicated agent mailbox safety model.
- `runbooks/bootstrap-recovery-lessons.md` - fresh-host setup and recovery notes.

## Durable Notes Areas

- `decisions/` - reusable decisions and rationale.
- `preferences/README.md` - durable preference examples.
- `state/` - templates for local current-state and host-state notes.
- `projects/README.md` - project note guidance.
- `ledger/README.md` - activity ledger guidance.
- `tasks/README.md` - task note guidance; local tasks are not shared here.
- `archive/README.md` - archive guidance.

## Merge Reminder

Copy or merge content into the local durable-notes root only after the Durable
Notes skill has initialized that hierarchy. Avoid overwriting local current
state, host facts, tasks, or credential metadata.
