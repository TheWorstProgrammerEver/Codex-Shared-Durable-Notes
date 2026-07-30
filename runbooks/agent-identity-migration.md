# Agent Identity Migration Between Hosts

Move an established Codex-managed agent as an identity and state restore, not
as a whole-disk clone. This procedure applies both across architectures, such
as ARM64 to amd64, and between hosts of the same architecture. A clean target
install, explicit state classification, parallel validation, and a retained
source host are safer than copying an installed operating system.

Creating support for a new operating system or architecture is a separate
adapter and provisioning task. An image builder may create the clean target,
but it does not decide which established agent state is portable or prove that
the restored identity works.

## Safety Invariants

- Keep the source host and its durable media intact until the retirement gate
  passes.
- Never boot or enable two write-capable instances of the same agent identity
  at once. Stop autonomous workers and single-writer applications on the source
  before their final delta or target activation.
- Keep credentials out of ordinary disk images, portable bundles, manifests,
  logs, and repositories. Prefer reauthentication.
- Restore portable data; reinstall architecture- and OS-specific components
  from supported sources.
- Verify bundle checksums before extraction and verify logical database
  integrity after receipt.
- Treat network storage as unavailable until its real endpoint resolves and
  accepts connections on the required service port.
- Make every decision and validation result traceable in a declarative restore
  brief without recording credential values or private host facts.

## Classify State Before Copying

Every inventory item must have exactly one disposition.

| Disposition | Typical contents | Migration action |
| --- | --- | --- |
| `portable` | Durable guidance and notes, selected Codex session/history state, text configuration, local skills, source repositories and dirty-worktree evidence, application data, service definitions, and portable user data | Snapshot consistently, checksum, restore, and validate |
| `rebuild-only` | OS packages, architecture-specific executables, npm or Python environments with native modules, containers selected by platform, compiled dependencies, kernel/firmware state, device rules, caches, temporary files, and generated build output | Record versions and sources, then reinstall or rebuild natively |
| `reauthenticate` | Codex login, OAuth sessions, short-lived tokens, cloud or SaaS integrations, and app installations that support a fresh authorization flow | Record non-secret purpose/scope metadata, then authorize afresh on the target |
| `restricted-secret-transfer` | A long-lived key or credential that cannot be reissued during the migration window | Transfer separately through an approved encrypted, access-restricted channel; verify custody and permissions; never place it in the ordinary bundle |

Do not classify a file as portable merely because both hosts use the same CPU
architecture. Installed binaries and compiled environments can still depend on
the old OS release, ABI, library set, filesystem layout, or device.

### Required Inventory

Inventory at least:

- durable-note roots, root guidance pointers, active task state, and relevant
  activity ledgers;
- selected Codex sessions, history, and database state needed for continuity;
- local skills and configuration, including the source and update path for each;
- Git repositories, branches, remotes, uncommitted changes, untracked files,
  submodules, worktrees, and recoverable Git bundles;
- services, timers, sockets, mount units, service accounts, enablement state,
  executable sources, writable paths, and ordering dependencies;
- application databases and the supported snapshot method for each;
- external integrations, their non-secret purpose and scope, and whether they
  will be reauthenticated or transferred under restriction;
- network-backed storage, endpoint type and port, mount ownership, offline
  behaviour, and every dependent service;
- installed tools and versions needed to rebuild the target; and
- state intentionally excluded, with a reason and owner approval where needed.

Search for valuable state beyond obvious home-directory files. A mounted-file
copy can miss partitions, databases with active write-ahead logs, service
accounts, or state owned outside the interactive account. If the source media's
coverage is uncertain or destructive reuse is contemplated, also follow
[Agent Media Preservation](agent-host-responsibility.md#agent-media-preservation).

## Use A Declarative Restore Brief

The brief is an operator-reviewed contract, not an executable secret store.
Use logical references rather than private local paths or endpoint names.

```yaml
schema: agent-identity-restore/v1
migration_id: example-2026-01-15
agent_identity: my-agent
source_platform:
  os_family: linux
  architecture: arm64
target_platform:
  os_family: linux
  architecture: amd64
items:
  - id: durable-notes
    disposition: portable
    source_ref: durable-notes-root
    bundle_path: portable/durable-notes/
    sha256: <sha256>
  - id: codex-cli
    disposition: rebuild-only
    install_source: supported-package-source
  - id: codex-login
    disposition: reauthenticate
    purpose: interactive-codex-access
  - id: repository-app-key
    disposition: restricted-secret-transfer
    secret_ref: operator-approved-secret-channel
services:
  - id: local-worker
    desired_state: enabled-after-validation
    writable_state: single-writer
    dependencies: []
network_mounts:
  - id: shared-corpus
    endpoint_ref: approved-storage-service
    readiness: dns-and-required-tcp-port
    dependent_services:
      - content-reader
validation_profile: parallel-cutover-v1
```

The real manifest should record sizes, digests, ownership/mode expectations
where portable, snapshot methods, tool versions, restore order, and validation
commands. It may contain secret references and credential metadata, but never a
credential value, private key, authentication cookie, private endpoint,
device identifier, or machine-private path.

## Migration Procedure

### 1. Establish Authority And A Rollback Hold

Name the source custodian, target operator, secret custodian, validation owner,
and person authorized to release the old host. Define:

- which source services may be stopped and when;
- which target services must remain disabled during staging;
- the acceptable final-delta downtime;
- the rollback trigger and maximum rollback window; and
- the source media and backups covered by the retirement hold.

Record a baseline identity check on the source: agent role, durable-note index,
expected configuration, current repository branches, integrations, enabled
services/timers, and application health. Exclude private values from shared
evidence.

### 2. Build A Consistent Portable Bundle

Prepare a staging tree that contains only `portable` state.

- Stop a writer or use its supported online snapshot mechanism. Copying a
  SQLite main file without its active WAL is not a consistent snapshot.
- Use SQLite's backup API or CLI `.backup` operation for live SQLite databases,
  then validate the received snapshot as described below.
- Preserve repository state with normal clones/fetches plus Git bundles,
  patches, or explicit copies for commits and dirty state not available from a
  remote. Verify that every recorded ref or dirty artifact is represented.
- Export service definitions and a service inventory; do not copy executables
  out of system package paths.
- Preserve file metadata only where the target filesystem and restore contract
  support it.
- Generate a manifest of relative path, type, byte size, and SHA-256 digest.
  Reject absolute paths, traversal components, links that escape the staging
  tree, special files, duplicate destinations, and unexpected entries.
- Create the archive from the reviewed staging tree, then checksum both the
  archive and manifest.

Create a separate restricted package only for approved
`restricted-secret-transfer` items. Encrypt or otherwise protect it using the
approved custody channel, restrict access, and set a deletion/rotation plan.
Do not nest it inside the portable archive.

### 3. Install The Target Natively

Install a clean, supported target OS for the target architecture. Verify the
release and architecture, install Codex through its supported path, and install
base tools needed to inspect and restore the bundle.

Recreate accounts, packages, native dependencies, runtimes, services, and
mount helpers from declarations or supported upstream sources. Do not restore:

- the source root filesystem;
- package-manager databases;
- copied system libraries or executables;
- source virtual environments or native-module directories;
- caches, temporary files, kernel state, firmware, or device-specific rules.

Keep autonomous workers, timers, write-capable applications, and network-backed
content services disabled through staging.

### 4. Receive, Verify, And Restore

Transfer the portable bundle and manifest through an approved transport.

1. Preserve the received archive as evidence.
2. Verify its SHA-256 digest and the signed or separately trusted manifest
   before extraction.
3. Inspect archive paths and types, then extract into a new staging directory
   rather than over live target state.
4. Compare every extracted item with the manifest. Reject missing, extra,
   mismatched, or unsafe entries.
5. Restore in declared order, preserving the target's clean OS ownership
   boundaries.
6. Install or build each `rebuild-only` item natively.
7. Reauthenticate integrations. Transfer an exceptional restricted secret only
   after its consumer is installed and ready, then validate permissions and
   remove staging residue according to the custody plan.
8. Record item-level results in the restore brief.

### 5. Prove SQLite Logical Integrity

A successful `.backup` operation or backup API return proves that pages were
transported; it does not prove indexes and table contents are logically
consistent.

For every received SQLite snapshot:

1. Keep the received database unchanged as a pre-repair artifact. Work on a
   copy and record both checksums.
2. Include any required auxiliary state through the application's supported
   snapshot operation; do not improvise with a live main-file copy.
3. Run `PRAGMA integrity_check;` against the received snapshot. Require the
   single result `ok`; command exit status alone is insufficient.
4. If the check fails, quarantine the snapshot and diagnose before starting its
   application. Preserve the received artifact even if another valid snapshot
   is available.
5. Confirm table data is intact using application invariants, counts, foreign
   key checks where applicable, and stable logical exports or row hashes that
   exclude indexes.
6. Use `REINDEX <diagnosed_index>;` only when evidence shows that table data is
   intact and a named index is the fault. Do not use a blanket `REINDEX` to
   conceal unknown corruption.
7. Rerun `PRAGMA integrity_check;`, repeat the table-data comparison, and record
   the repaired database checksum. Retain the pre-repair artifact under the
   migration retention policy.

Run the repository fixture to exercise the boundary:

```bash
tests/fixtures/sqlite-index-corruption.sh
```

The fixture creates an index inconsistency, confirms `.backup` succeeds,
detects the inconsistency in the received snapshot, preserves the received
pre-repair file, applies a named `REINDEX`, and proves table rows did not
change.

### 6. Gate Network-Backed Services On The Endpoint

`network-online.target` means the local network manager considers the host
online. It does not prove that DNS/mDNS resolution, Wi-Fi routing, a NAS, or its
required service is ready.

For every network mount:

- create a bounded readiness step that resolves the configured endpoint and
  establishes a TCP connection to the required service port;
- order the mount after and require that readiness step;
- order each dependent service after and require the mount;
- add a pre-start mountpoint assertion so an ordinary local directory cannot
  masquerade as the remote filesystem;
- use bounded retries with inspectable status and logs, and explicitly requeue
  the mount-and-service chain after late endpoint recovery;
- keep the dependent service stopped when readiness or mounting fails; and
- provide an explicit retry/recovery path for late endpoint availability.

A systemd implementation may use this dependency shape:

```ini
# endpoint-ready.service
[Unit]
Wants=network-online.target
After=network-online.target
Before=mnt-shared\x2dcorpus.mount

[Service]
Type=oneshot
EnvironmentFile=/etc/my-agent/storage-endpoint.env
ExecStart=/usr/local/libexec/wait-for-storage-endpoint
Restart=on-failure
RestartSec=15s

# mnt-shared\x2dcorpus.mount adds:
Requires=endpoint-ready.service
After=endpoint-ready.service

# content-reader.service adds:
Requires=mnt-shared\x2dcorpus.mount
After=mnt-shared\x2dcorpus.mount
ExecStartPre=/usr/bin/mountpoint -q /mnt/shared-corpus
```

The readiness helper reads a non-secret endpoint reference and port from the
restricted local environment file, uses the platform's resolver, and attempts
the actual TCP service connection. It must not log private endpoint values or
credentials. Adapt unit names and paths to the clean target; do not copy them
blindly from the source. Unit ordering does not by itself requeue a mount job
that already failed. Use a bounded local retry timer or recovery service that
starts the mount again and starts dependents only after the mount succeeds and
the mountpoint assertion passes.

### 7. Validate In Parallel

Keep the source available but passive while the target is tested. Never allow
both instances to run autonomous jobs or write the same remote state.

| Scenario | Required evidence |
| --- | --- |
| Clean install | Target booted from its supported native OS; no copied system executables or package state are in use |
| Identity and notes | Agent role, root guidance, durable-note index, current state, selected history, and configuration match the approved inventory |
| ARM-to-amd64 | Every rebuild-only item is native to the target; portable data and service behaviour pass |
| Same-architecture replacement | The same classification and clean-install controls pass; architecture equality did not permit whole-OS copying |
| Repositories and skills | Expected refs, dirty-state artifacts, remotes without embedded credentials, local skills, and update sources are present |
| SQLite | Every received snapshot returns `ok`; the inconsistent-index fixture is detected, its pre-repair artifact remains unchanged, and narrow repair preserves table data |
| Reauthentication | Each external integration performs a read-only check and, where authorized, one bounded write/action check without exposing credentials |
| Services and timers | Inventory matches the target; staged services remain disabled until approved; enablement, service account, restart, logs, and writable paths are correct |
| Delayed Wi-Fi or storage | Endpoint readiness waits; the mount and dependent services remain stopped; they recover through the declared retry path once resolution and the service port work |
| Storage unavailable at boot | Boot reaches a manageable state; no local-directory fall-through occurs; dependent services stay stopped with useful status |
| Live network outage | Dependent applications fail safely or stop according to policy, do not write to a local fallback path, and recover cleanly after the endpoint returns |
| Reboot | Identity, mounts, service ordering, timers, and headless operator access work after at least one cold or full reboot |
| Rollback | Target writers can be stopped, source state can be reconciled under the declared data-authority rule, and the source can resume without two active identities |
| Retirement | Independent backup and restore evidence, final checksums, validation sign-off, and explicit release authority are all present |

Record actual commands, timestamps, results, and artifact checksums in
local/private migration evidence. Record only redacted summaries in shared
systems.

### 8. Final Delta And Cutover

After staged validation:

1. Stop source writers and autonomous workers.
2. Take a final consistent delta and database snapshots.
3. Transfer, checksum, restore, and re-run integrity and identity checks.
4. Confirm the source remains passive.
5. Enable target mounts and services one at a time, starting with read-only
   dependencies and ending with write-capable or autonomous workloads.
6. Run the delayed-endpoint, outage/recovery, and reboot scenarios again in the
   final network and naming context.
7. Declare the target authoritative and record the cutover point.

## Rollback

Rollback is an explicit authority transfer, not merely powering on the source.

- Stop target autonomous and write-capable services first.
- Determine whether the target produced authoritative writes after cutover.
- Reconcile or restore those writes using the application's supported method;
  do not copy a live database backwards.
- Verify the source's database integrity, mounts, credentials, and service
  inventory.
- Re-enable the source in dependency order and prove the target is passive.
- Record the rollback reason and preserve both migration evidence sets.

If authoritative target writes cannot be reconciled safely, stop and escalate.
Do not create two divergent active copies of the identity.

## Source-Host Retirement Gate

The old host or its media is safe to repurpose only when all of these are true:

- the final bundle, manifest, received artifacts, and independent backup verify
  by checksum;
- each database and application restore passes logical integrity and functional
  checks;
- identity, notes, configuration, repositories, skills, integrations, services,
  timers, network mounts, delayed availability, live outage/recovery, and reboot
  validation pass;
- target behaviour has remained stable for the approved observation window;
- the rollback procedure has been exercised or reviewed with sufficient
  evidence, and authoritative post-cutover data has a recovery path;
- secret staging artifacts have been removed or retained only under the
  approved restricted custody policy; and
- the named release authority explicitly releases the source-host hold.

Powering down the source is reversible and does not itself release the hold.
Until release, do not format, image, repartition, wipe, lend, or repurpose its
storage.

## Setup And Image Guidance Boundary

Fresh-host bootstrap and boot-image guidance remains useful for creating the
clean target. It is not an established-agent migration procedure and is
superseded by this runbook for deciding what identity state to preserve,
restore, validate, roll back, or retire. Do not restore a setup repository as a
substitute for inventorying the live agent, and do not extend a restore
procedure with a new OS/architecture adapter implicitly.

## Source

- [RYA-206 - Document cross-architecture agent identity migration](https://linear.app/ryan-hayward/issue/RYA-206/hive-mind-document-cross-architecture-agent-identity-migration)
- [RYA-121 - Agent Boot Image CLI architecture](https://linear.app/ryan-hayward/issue/RYA-121/spec-agent-boot-image-cli-end-to-end-architecture-and-delivery)
