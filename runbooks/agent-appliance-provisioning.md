# Small Headless Agent Appliance Provisioning

Use this runbook to commission a dedicated small-computer Codex agent as a
headless appliance. It defines the reusable platform beneath the agent's role.
Role prompts, work adapters, credentials, external integrations, and task
schedules remain explicit overlays.

This page owns the composition, commissioning order, and acceptance gates. Use
the linked guidance for the detailed implementation mechanics rather than
copying those mechanics into each appliance definition.

## Composition Model

- **Host:** the baseline supplies a minimal supported OS, dedicated account,
  network recovery, time sync, unattended privilege, SSH, and a persistent
  operator session. The overlay supplies agent identity, hostname, network
  inputs, and local access policy.
- **Cognition:** the baseline pins Codex/runtime versions and supplies a
  deterministic permission profile, manual authentication gate, and
  post-cognition verification. The overlay supplies the role charter,
  model/reasoning choice, and authored cognition prompt.
- **Git:** the baseline supplies Git, the per-agent GitHub App helper mechanism,
  and protected credential placement. The overlay supplies the app identity,
  repository allowlist, scopes, and pinned repositories.
- **Memory:** the baseline supplies skills, Durable Notes, Shared Durable Notes,
  shared guidance, and Mind Maintainer. The overlay supplies local role,
  project, and task state.
- **Host care:** the baseline supplies inspectable service/timer installation
  and low-write drive-health capability. The overlay supplies agent-specific
  policy and cadence.
- **Work:** the baseline supplies the reviewed adapter boundary, overlap
  control, bounded logs/status, canary, timer proof, and recovery contract. The
  overlay supplies natural-language intent, realized task definitions,
  credentials, and allowed external effects.

A Linear work or review delegator is an overlay, not part of the appliance
baseline. The same rule applies to messaging, email, payments, and every other
integration that can cause an external effect.

Two role checks keep that boundary honest:

- A reviewer may add a Linear review adapter, reviewer-specific credentials,
  repository access, and a review cadence. The baseline must still be usable
  before that overlay is installed or while it is disabled.
- A maintenance agent can use the same baseline with drive-health and memory
  maintenance tasks but no Linear adapter, states, labels, or credentials.
  Baseline validation must not look for them.

For either role, every task the overlay enables must satisfy the complete
definition, live-canary, finite-next-trigger, and post-reboot evidence contract
below.

## Deterministic And Cognitive Responsibilities

Use cognition to interpret purpose and intent. Use deterministic code for
permissions, credentials, installation, state transitions, and proof.

The image, installer, and runner own:

- exact OS, runtime, Codex, and repository revisions;
- account creation and a proven non-interactive privilege path;
- protected secret placement and removal of bootstrap copies;
- account-owned mutable home directories and ancestors;
- populated Git checkouts, clean-tree gates, and revision verification;
- systemd unit generation, runtime environment, enablement, re-arming, and
  exact-unit status checks;
- SSH key installation and the final authentication-policy cutover; and
- static checks, live canaries, reboot checks, and bounded recovery.

A high-reasoning cognition step may:

- read the role charter and natural-language recurring-task intent;
- select a reviewed adapter or schedule template already present;
- write explicit, inspectable task definitions and local role notes;
- self-review whether the resulting plan matches the stated role; and
- propose missing tooling instead of improvising an unsafe daemon.

Cognitive output is an input, not completion evidence. A deterministic
validator must parse every realized definition, verify its adapter and units,
exercise the installed service path with a bounded live canary, and prove the
timer has a finite future trigger. Secret values must not enter prompts,
generated notes, logs, or validation reports.

## Ordered Commissioning

1. **Define the appliance and overlay.** Start with role-neutral recipe
   components and one small, explicit overlay. Pin supported revisions and keep
   secret inputs byte-exact, private, and outside Git and durable notes.
2. **Preflight the image and target.** Verify immutable source artifacts,
   preserve identity-bearing media when required, authorize the exact target,
   validate the complete placement plan and capacity, perform the write and
   read-back, then run read-only filesystem checks after customization.
3. **Reach and recover the headless host.** Prove a local/offline recovery path,
   provision two independently usable public-key access paths, and establish a
   persistent operator session. Keep temporary password access until the SSH
   cutover gate passes.
4. **Prove unattended privilege.** Require `sudo -n true` for the dedicated
   account before any automatic step depends on privilege.
5. **Complete Codex authentication.** Run the supported manual device or OAuth
   flow through a separate operator session when required. Let a bounded,
   redacted completion probe resume the runner.
6. **Establish cognition.** Run the authored role prompt with the intended model
   and reasoning setting. Checkpoint its completion, but treat its output only
   as input to deterministic realization and verification.
7. **Install the reusable baseline.** Install Git and scoped GitHub App helpers,
   pinned shared repositories, skills, durable/shared notes, Mind Maintainer,
   drive health, and the standard service/timer verification capability.
8. **Realize task intent.** Convert each natural-language recurring task into an
   inspectable definition using a reviewed adapter. Keep role-specific work
   delegators in the overlay.
9. **Validate statically and live.** Verify protected files, ownership,
   checkouts, installed skills, generated definitions, exact installed units,
   one harmless service canary per task, timer enablement/activity/finite next
   trigger, bounded observability, and empty bootstrap-secret storage.
10. **Harden SSH transactionally.** Validate the complete candidate, reload
    rather than stop SSH, inspect the effective policy, prove fresh key-only
    logins through both intended key paths, and prove a password-only client is
    offered no password method.
11. **Reboot and prove durability.** Confirm the bootstrap runner does not
    replay completed cognition or once-only effects, every intended timer
    re-arms with a finite future activation, service canaries still work,
    protected state remains private, and the old temporary access path stays
    disabled.

Detailed image, bootstrap, secret, network, and failure-recovery mechanics live
in [Bootstrap Failure And Recovery Lessons](bootstrap-recovery-lessons.md).
Use [Agent Host Responsibility](agent-host-responsibility.md) for media
preservation and host-state boundaries, and
[Headless Operator Flows](headless-operator-flows.md) for offline recovery,
SSH, persistent sessions, and browser OAuth.

## Field-Proven Gates

The following checks must pass before the first dependent automatic step:

- **Privilege:** `sudo -n true` succeeds for the dedicated account. Discovering
  interactive sudo inside an automatic step can exhaust its retry budget
  before an operator can repair the prerequisite.
- **Ownership:** every new mutable directory beneath the account home is owned
  by that account, including ancestors for SSH, configuration, repositories,
  and durable notes. Correct leaf ownership is not sufficient.
- **Git:** a fresh checkout has a populated worktree before the dirty-tree gate.
  A `--no-checkout` clone can appear as tracked deletions and must not be
  misclassified as ordinary local modification.
- **Private runtime:** a service that launches a private npm/Node bundle has an
  explicit `PATH` containing the matching runtime. An npm launcher with an
  `env node` shebang can pass an interactive check and still fail under
  systemd.
- **Installed service:** static unit verification is followed by a start
  through the target system manager. This proves the actual account, paths,
  namespace, interpreter, and environment reach `ExecStart`.
- **Recurring timer:** every enabled timer is enabled, active, and armed with a
  finite future activation. After final unit publication and `daemon-reload`,
  reinstallers deliberately restart or otherwise re-arm an already-active
  timer; `enable --now` alone is not a repeat-install transition.
- **SSH:** both intended public-key paths work before password authentication is
  removed. Post-cutover proof uses fresh external key-only sessions and a
  negative password-only probe, not only an established safety session.

Use the coding-style skill's detailed
[packaged-runtime verification](https://github.com/TheWorstProgrammerEver/codex-skills/blob/main/coding-style/references/packaged-runtime-verification.md)
and
[systemd timer lifecycle](https://github.com/TheWorstProgrammerEver/codex-skills/blob/main/coding-style/references/systemd-timer-lifecycle.md)
guidance for implementation and tests. The
[GitHub App PR Workflow](github-app-pr-workflow.md) owns scoped repository
authentication and publication mechanics.

## Recurring Task Definition Contract

Natural language is the source of task intent, not the runtime schedule or its
completion evidence. Store the realized result in a versioned, inspectable
definition. The format may be TOML, YAML, JSON, or another parsed schema, but it
must reject unknown and invalid fields rather than silently guessing.

Each recurring task definition records at least:

- **Identity:** stable task identifier, human-readable purpose, owner, and
  success condition.
- **Implementation:** reviewed command or adapter, immutable revision when
  applicable, service account, working directory, and explicit runtime
  environment.
- **Schedule:** cadence, timezone semantics, jitter, persistence/catch-up
  policy, and the event that re-arms the next run.
- **Bounds:** timeout, retry budget, cancellation behavior, overlap prevention,
  and maximum queued or catch-up work.
- **Inputs:** non-secret inputs plus protected credential references by purpose
  and location; never embedded values.
- **Effects:** declared local and external effects, remote idempotency key
  strategy, durable intent/result states, reconciliation rule, and
  ambiguous-result policy.
- **Observability:** bounded logs, last-run status, stable failure codes, and
  operator inspection commands.
- **Lifecycle:** install, validate, enable, disable, manual-run, reconcile,
  uninstall, and cleanup operations.
- **Proof:** deterministic schema/unit checks, harmless live canary, exact-unit
  enabled and active checks, finite next-trigger check, and post-reboot re-arm
  check.

Prefer calendar timers when recurrence must continue even if a oneshot service
is condition-skipped and therefore never establishes a service-state-relative
anchor. Choose catch-up behavior deliberately; do not add persistence merely
because it is available.

For each task that should remain scheduled, the acceptance evidence is the
conjunction below. No individual result substitutes for another:

1. the realized definition parses and names a reviewed adapter;
2. static unit verification passes;
3. the installed service completes one bounded, harmless live canary;
4. the exact timer is enabled;
5. the exact timer is active;
6. the exact timer reports a finite future trigger; and
7. after reboot, the timer is again enabled, active, and finitely armed, and a
   service canary still reaches the installed entrypoint.

The [Linear Local Worker Model](linear-local-worker.md) is one optional overlay
example. Its presence must never be assumed by the baseline or by a maintenance
agent that has no Linear role.

## Replay And Ambiguous Results

Before an external effect, durably record the exact intent and stable operation
identity. Prefer a provider-supported idempotency key. After the call, record
the result and reconcile it against the remote system before committing local
completion.

If the process can crash after the remote effect succeeds but before local
completion is durable, classify the recovered outcome as ambiguous. Reconcile
through the stable operation identity when the provider supports it; otherwise
stop in a fail-closed manual-review state. Never infer that absence of a local
success marker makes replay safe, and never let a model decide to resend from
free-form logs.

Retry budgets include ambiguous in-flight attempts. Completed cognition,
credential creation, notifications, task claims, payments, and other once-only
effects must not replay merely because a later commissioning step failed.

## Plan-Bound Suffix Recovery

Automatic steps need bounded retries and inspectable terminal failure. Do not
edit or delete a runner checkpoint to force progress, and do not restart the
whole plan when completed steps may have external effects.

A supported suffix recovery operation must:

- parse the failed checkpoint and validate its cross-field semantics;
- bind it to the exact immutable source plan, step identities, ordering, and
  revision;
- preserve the original terminal state as evidence;
- create a separate recovery identity and checkpoint;
- begin only at the reviewed failed suffix;
- reject plan, ordering, credential-reference, or immutable-asset drift;
- account for ambiguous in-flight attempts without resetting their budget; and
- run the same final postconditions and reboot proof as an uninterrupted plan.

If the provisioning tool does not implement this operation, treat a hand-built
suffix runner as supervised incident recovery, not a reusable feature. The
coding-style skill's
[recovery validation boundaries](https://github.com/TheWorstProgrammerEver/codex-skills/blob/main/coding-style/references/general-implementation.md#recovery-validation-boundaries)
own the detailed validation layers. For an established identity moving between
hosts, use [Agent Identity Migration Between Hosts](agent-identity-migration.md)
instead of treating migration as fresh provisioning.

## Two-Consumer Extraction Rule

Keep the first appliance implementation close to its reviewed definition. Use
the second appliance as an independent consumer of the same recipe and let the
two concrete definitions reveal stable boundaries.

Extract an Agent Boot helper only when:

- both consumers require the same behavior and postconditions;
- the proposed interface excludes role, credential, host, and task identity;
- focused tests cover success, repeat installation, interruption, failure,
  cleanup, and redaction at that boundary; and
- both appliance definitions adopt the helper without weakening their live
  canary and reboot evidence.

Do not freeze a speculative framework for one consumer, and do not copy a
proven boundary into a third appliance. Typical candidates include unattended
privilege preflight, ownership-aware home placement, populated pinned Git
checkout, private-runtime service environment, verified timer re-arming,
transactional SSH cutover, and plan-bound suffix recovery.

## Acceptance Record

Keep one redacted commissioning record that names immutable revisions and
records pass/fail for every gate. It should contain no secret values, private
network facts, device identifiers, or host-local paths.

At minimum, record:

- baseline and overlay definitions reviewed;
- deterministic setup and cognition checkpoints complete;
- every recurring task definition parsed and adapter reviewed;
- every enabled task's static check, live canary, enabled state, active state,
  finite next trigger, and post-reboot re-arm proof;
- both SSH key paths and the password-only negative probe;
- replay/ambiguity and suffix-recovery policies reviewed; and
- reboot evidence showing no completed once-only effect replayed.
