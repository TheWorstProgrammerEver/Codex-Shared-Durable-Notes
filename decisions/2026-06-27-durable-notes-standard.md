# Durable Notes Standard

Date: 2026-06-27

## Decision

Use `~/codex-notes` as the canonical durable memory hierarchy for Codex-managed
host context, as defined by the Durable Notes skill.

## Rationale

- Root-level files are easy to discover but do not scale well.
- A small hierarchy keeps active work, host state, runbooks, decisions, project
  context, preferences, ledger history, and credential metadata separate.
- Skills and future bootstrap runs can initialize the same layout without
  guessing where persistent context belongs.

## Rules

- Store no secrets, private keys, tokens, passwords, recovery codes, or full
  credential values.
- Keep root files as pointers for discoverability.
- Prefer concise dated notes with concrete commands, paths, artifacts, and next
  steps.
- Mark superseded facts explicitly instead of silently deleting useful history.
