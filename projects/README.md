# Project Notes

Use project notes for stable context that future agents need before changing a
repo or operating a service.

Good project notes include:

- repository URL;
- local clone path;
- current branch or release state;
- relevant Linear issues;
- important PRs or commits;
- validation commands;
- operational services or timers;
- known blockers;
- links to runbooks and decisions.

Do not copy local clone paths from another agent into a new host as if they were
facts. Treat shared project notes as patterns to merge, not authority over local
state.
