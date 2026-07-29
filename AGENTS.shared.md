<!-- BEGIN SHARED_AGENT_GUIDANCE -->
Shared guidance maintained from `Codex-Shared-Durable-Notes/AGENTS.shared.md`.
Do not edit this block directly; update the shared source and let Mind Maintainer merge it.

- For substantial work, inspect relevant durable notes, shared durable notes, repo guidance, or installed skills before acting when they are likely to contain useful prior knowledge.
- Before finishing substantial work, run a Hive Mind check. If the task produced a reusable procedure, durable lesson, skill improvement, shared-note update, shared-AGENTS guidance update, or obsolete collective guidance, use the Agent Hive Mind skill to create a Linear issue in `Backlog`. Do not assign the issue unless explicitly asked. Include the target repo, source context, proposed change, acceptance criteria, validation, model label, and reasoning label.
- Do not record secrets, credentials, private keys, tokens, passwords, recovery codes, local-only host facts, private paths, local IP addresses, or device identifiers in shared intelligence.
- In a workspace with nested Git checkouts, `apply_patch` has no per-call working directory: prefix patch paths with the intended checkout path and verify them immediately. After large additions or moves, run `git status --short` in the target repo; if expected files are missing, check the workspace root before continuing.
- For GitHub work that requires push, PR, or API authentication on a Codex-managed host, first inspect host-specific durable notes or runbooks for scoped GitHub App helpers such as `GIT_ASKPASS` or a `gh` wrapper. Prefer those helpers over `gh auth login`, personal access tokens, browser or device authentication, or assuming connector credentials apply to local Git. Do not print tokens or private keys, and do not preserve local credential paths in shared guidance.
- Before destructive operations on removable media or disks that may contain agent state, treat the media as valuable: identify the likely agent, prefer a whole-device image plus metadata and checksums when filesystem coverage is uncertain, and confirm the backup before formatting, imaging, repartitioning, or reuse.
<!-- END SHARED_AGENT_GUIDANCE -->
