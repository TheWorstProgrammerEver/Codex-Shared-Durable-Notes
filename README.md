# Codex Shared Durable Notes

This repository is a shared, source-controlled knowledge base for Codex agents
and operators. It contains reusable durable notes that can be copied or merged
into an agent's local durable-notes hierarchy.

## Naming

The conceptual name requested for this knowledge base was
`Codex-Agent-Shared-Durable-Notes`. The GitHub repository created for it is
`Codex-Shared-Durable-Notes`.

This repo intentionally uses the shorter GitHub name while documenting the
conceptual name here so future agents do not treat the mismatch as accidental.

## Required Dependency

Install the Durable Notes skill first from the
[Codex Skills repository](https://github.com/TheWorstProgrammerEver/codex-skills).

The Durable Notes skill defines the canonical filesystem structure this repo is
designed to merge into. If the schema defined by that skill changes, this shared
durable notes repository may need to be updated to match.

## Shared AGENTS Guidance

The source-controlled shared `AGENTS.md` guidance lives at `AGENTS.shared.md`.
It is intentionally short and marked with `BEGIN SHARED_AGENT_GUIDANCE` /
`END SHARED_AGENT_GUIDANCE` comments so setup and maintenance tools can refresh
only the shared block without clobbering host-specific local instructions.

Detailed decision trees, templates, and rubrics belong in skills or durable
notes. The shared block should stay concise enough to be always loaded.

## How To Use

Do not run an install script; none is provided. Review and merge the Markdown
files manually.

Recommended flow:

1. Install the Durable Notes skill and initialize local durable notes.
2. Review this repository's `INDEX.md`, `AGENTS.shared.md`, and the files under `runbooks/`,
   `decisions/`, `preferences/`, `credentials/`, `state/`, and `projects/`.
3. Copy useful files into the matching local durable-notes directories.
4. Merge carefully when a local file already exists, especially
   `INDEX.md`, `state/HOST.md`, `state/CURRENT.md`, `tasks/TODO.md`, and
   `credentials/NOTES.md`.
5. Merge `AGENTS.shared.md` only into the managed shared guidance block in the
   local root `AGENTS.md`.
6. Preserve local host facts, tasks, project state, and credential metadata that
   belong only to that agent.
7. Record only credential purpose, location, owner, scope, and revocation or
   rotation steps. Never store secret values.

## Repository Shape

The hierarchy mirrors the durable-notes layout while avoiding local-only state:

```text
AGENTS.shared.md
INDEX.md
runbooks/
decisions/
preferences/
credentials/
state/
projects/
ledger/
tasks/
archive/
```

Shared content is deliberately shallow and searchable. Local agents should add
their own current state, host facts, tasks, and activity ledger entries after
merging.

## Scope

This repo should contain reusable agent knowledge:

- durable notes memory model and merge habits;
- local agent host responsibility principles;
- GitHub App pull request workflow;
- Linear local-worker operating model;
- headless SSH and OAuth operator patterns;
- credential metadata rules;
- automated testing cleanup expectations;
- agent email identity safety;
- bootstrap failure and recovery lessons;
- Kiwix-first offline knowledge reservoir setup for local agents and humans.
- wake-word, post-wake transcription, and command-confirmation architecture for
  microphone-enabled local agents.

Do not add host names, local IP addresses, device serials, private paths,
personal anecdotes, one-off task logs, plaintext secrets, private keys, tokens,
passwords, recovery codes, or Wi-Fi credentials.
