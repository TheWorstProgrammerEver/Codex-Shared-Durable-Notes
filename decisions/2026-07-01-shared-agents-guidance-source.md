# Shared AGENTS Guidance Source

Date: 2026-07-01

## Decision

The source-controlled shared `AGENTS.md` guidance lives in this repository at
`AGENTS.shared.md`.

## Rationale

This repository already owns shared reusable durable knowledge for Codex agents,
so the always-loaded guidance can live beside the durable notes it points agents
toward. Keeping the file here avoids blocking setup work on a new standalone
repository while still giving Mind Maintainer a stable source path to fetch and
merge into local `AGENTS.md` files.

The file contains only the managed shared block. Host-specific `AGENTS.md`
content remains local, outside the managed markers.

## Consumers

- `Codex-Agent-Setup` seeds this guidance into new hosts during the Codex
  permissions/bootstrap phase.
- Future Mind Maintainer work should refresh only the managed block delimited by
  `BEGIN SHARED_AGENT_GUIDANCE` and `END SHARED_AGENT_GUIDANCE`.
