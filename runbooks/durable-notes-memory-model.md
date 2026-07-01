# Durable Notes Memory Model

Durable notes should act like a practical wiki crossed with an activity ledger.
They preserve useful recall across agent sessions while keeping current state
fast to inspect, search, and act on.

## Memory Types

Use separate note shapes for separate jobs.

Current state:

- active host facts;
- installed services and timers;
- current project state;
- active task queue and blockers;
- credential metadata locations, never secret values.

Activity ledger:

- meaningful sessions;
- major pull requests;
- scheduler installs or removals;
- bootstrap experiments;
- incidents, recoveries, and validation results;
- preferences that emerged through interaction.

Semantic wiki:

- project pages;
- runbooks;
- decisions;
- credential metadata;
- host state;
- coding and testing preferences.

Procedural memory:

- repeatable runbooks;
- Codex skills;
- review workflows;
- bootstrap procedures;
- operational checklists.

Preference memory:

- user priorities;
- risk posture;
- repeated cautions;
- patterns to prefer or avoid.

## Promotion Flow

Use this pipeline:

1. Conversation or task context produces raw facts.
2. Meaningful history goes into a dated ledger entry or relevant project note.
3. Stable procedures become runbooks or skills.
4. Architectural and operational choices become decision records.
5. Current operational facts update state, project, or task pages.
6. Superseded information is marked historical or moved to archive, not silently
   deleted.

## Searchability Rules

- Prefer plain Markdown with predictable paths.
- Use concrete names for repos, PRs, Linear issues, services, timers, commands,
  and logs.
- Add dates to entries and decisions.
- Link related notes, commits, PRs, issues, and runbooks.
- Keep current-state pages short enough for quick orientation.
- Move long narrative history into the ledger.

## Start-Of-Session Read Path

On a configured host, read:

1. root `AGENTS.md`, if present;
2. root `CODEX_TODO.md`, if present;
3. local durable notes `INDEX.md`;
4. relevant state, project, runbook, decision, preference, credential, and
   ledger files based on the task.

## End-Of-Task Memory Check

Before finishing substantial work, ask whether any of these changed:

- current state;
- active tasks;
- project state;
- services or timers;
- external integrations;
- decisions or rationale;
- repeated procedures;
- user preferences or risk posture;
- credential metadata;
- useful history worth preserving.

If yes, update the narrowest durable note and avoid storing secret values.
