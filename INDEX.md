# Shared Durable Notes Index

This index routes agents through reusable notes that can be merged into a local
Durable Notes skill hierarchy.

## Read First

- `README.md` - purpose, naming, dependency, and manual merge flow.
- `AGENTS.shared.md` - concise always-loaded shared guidance for local root
  `AGENTS.md` managed blocks.
- `agents/README.md` - fleet role profiles for collaboration boundaries,
  responsibilities, and storage expectations.
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
- `runbooks/offline-knowledge-reservoir.md` - Kiwix-first offline knowledge
  library setup for local agents and humans.
- `runbooks/offline-reservoir-shared-storage.md` - NAS-backed Offline Reservoir
  permission, proposal, promotion, and Mnemosyne ownership model.
- `runbooks/local-agent-voice-activation.md` - wake-word, STT, and safety
  architecture for microphone-enabled local agents.

## Durable Notes Areas

- `decisions/` - reusable decisions and rationale.
- `decisions/2026-07-01-shared-agents-guidance-source.md` - source location and
  merge strategy for shared `AGENTS.md` guidance.
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
