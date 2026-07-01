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

## How To Use

Do not run an install script; none is provided. Review and merge the Markdown
files manually.

Recommended flow:

1. Install the Durable Notes skill and initialize local durable notes.
2. Review this repository's `INDEX.md` and the files under `runbooks/`,
   `decisions/`, `preferences/`, `credentials/`, `state/`, and `projects/`.
3. Copy useful files into the matching local durable-notes directories.
4. Merge carefully when a local file already exists, especially
   `INDEX.md`, `state/HOST.md`, `state/CURRENT.md`, `tasks/TODO.md`, and
   `credentials/NOTES.md`.
5. Preserve local host facts, tasks, project state, and credential metadata that
   belong only to that agent.
6. Record only credential purpose, location, owner, scope, and revocation or
   rotation steps. Never store secret values.

## Repository Shape

The hierarchy mirrors the durable-notes layout while avoiding local-only state:

```text
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
- bootstrap failure and recovery lessons.

Do not add host names, local IP addresses, device serials, private paths,
personal anecdotes, one-off task logs, plaintext secrets, private keys, tokens,
passwords, recovery codes, or Wi-Fi credentials.
