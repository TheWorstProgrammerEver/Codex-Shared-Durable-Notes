# Testing Cleanup Practices

Tests must clean up after themselves. A passing test suite that leaves temp
directories, state files, lock files, spawned processes, timers, services,
environment changes, or global state behind is still faulty.

## Filesystem Cleanup

- Wrap created directories and files in `try`/`finally`.
- Use idempotent cleanup operations.
- Avoid helpers that allocate temp files or directories implicitly.
- Beware defaults that create temp paths before caller overrides are applied.
- Use test-specific temp prefixes so leftovers are easy to detect and safe to
  inspect.

Example before/after check:

```bash
find /tmp -maxdepth 1 -type d -name 'project-prefix-*' -printf '%f\n' | sort > /tmp/project-before.txt
npm test
find /tmp -maxdepth 1 -type d -name 'project-prefix-*' -printf '%f\n' | sort > /tmp/project-after.txt
comm -13 /tmp/project-before.txt /tmp/project-after.txt
```

The final command should produce no output.

## Process And Service Cleanup

- Wait for spawned processes to exit or terminate them explicitly.
- Use controlled fakes when the process boundary is not under test.
- Isolate service, timer, hook, lock, and scheduler state under a temp root.
- Avoid writing to real user or system locations unless the test is explicitly
  an integration test and cleanup is validated.

## Environment Cleanup

Restore mutated process-wide state in `finally`, including:

- environment variables;
- current working directory;
- global console methods;
- fake timers;
- signal handlers;
- singleton or module-level state.

## Review Checklist

- Search tests for temp creation APIs.
- Confirm every allocation has a cleanup path.
- Check helpers for hidden side effects.
- Run the relevant test command.
- When filesystem state matters, run a before/after leftover scan.
