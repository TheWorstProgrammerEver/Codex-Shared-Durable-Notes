# Offline Reservoir Shared Storage Model

Use this runbook when multiple local agents or approved humans need to read from
the same offline knowledge reservoir, especially when bulky archives move from a
single host disk to NAS-backed storage. Treat the Offline Reservoir as shared
local knowledge with a change process, not just a Kiwix service or a casual file
share.

Kiwix is the first serving layer. The durable system is broader: curated
corpora, provenance, refresh policy, catalogs, retrieval surfaces, backups,
snapshots, and owner-approved promotion into canonical storage.

The fleet's deployed storage substrate is
[Olympus](../projects/olympus-nas.md). That baseline identifies the concrete
appliance, current reservoir integration, and facts that require live
verification; this runbook remains authoritative for storage workflow and
permissions.

For a separate community-library appliance that copies an approved read-only
export, owns its client network, and promotes only its local staged release, use
`runbooks/offline-community-library-appliance.md`.

## Default Boundary

- Approved shared corpora, Kiwix ZIM archives, catalogs, public docs, and
  backups are read-only for ordinary agents by default.
- Ordinary agents may propose additions, removals, refreshes, catalog fixes, and
  retrieval improvements.
- Ordinary agents write only to explicit owned namespaces such as inbox,
  staging, job output, or backup output.
- Canonical mutation flows through a human owner-approved workflow or a
  dedicated storage-owner agent.
- Mnemosyne is the planned concrete storage-owner agent for NAS structure,
  promotion, retention, snapshots, repair, indexing, and deletion.

Humans retain owner override and recovery authority. Do not grant a
general-purpose agent broad NAS write access merely because it can mount or
consume the reservoir.

## Host-Neutral Layout

Use placeholders in shared guidance and implementation templates. Replace them
with local mount points only in host-local notes or deployment config.

```text
<nas-root>/
  offline-knowledge/
    canonical/
      zim/
      manifests/
      catalog/
      docs/
      corpora/
    incoming/
      <storage-owner>/
    proposals/
      <agent-name>/
    snapshots/
    repair/
    library.xml
  agents/
    <agent-name>/
      inbox/
      staging/
      backups/
      jobs/
  shared/
    public-docs/
    catalogs/
```

`canonical/` is shared truth. Ordinary agents read it and should not mutate it.
`agents/<agent-name>/` is owned workspace for one agent. `proposals/` is for
content that may become shared after validation. `incoming/`, `repair/`, and
`snapshots/` are storage-owner work areas unless the owner explicitly delegates
a narrower task.

Local deployments may expose a simpler service root such as
`<reservoir-root>/zim`, `<reservoir-root>/manifests`,
`<reservoir-root>/catalog`, and `<reservoir-root>/library.xml`. Keep the
permission boundary the same even if the directory tree is flatter.

## Promotion Workflow

Use proposal and promotion instead of casual shared writes:

1. An ordinary agent writes a proposal under its owned namespace with source
   URLs, retrieval date, intended destination, license/provenance notes,
   expected size, checksum source, and validation plan.
2. The agent downloads or generates artifacts only in its own staging area
   unless the storage owner grants a specific shared job namespace.
3. Mnemosyne or an owner-approved process validates source integrity, license,
   freshness, corpus fit, manifest quality, catalog impact, and storage
   headroom.
4. The storage owner promotes accepted artifacts into canonical storage with an
   atomic or auditable move/copy, updates manifests and catalogs, and records
   provenance.
5. Serving layers reload or restart after canonical metadata changes.
6. The storage owner snapshots or backs up the new state, then removes rejected
   or superseded proposal artifacts according to retention policy.

Removal should follow the same discipline. Agents can propose deletion or
replacement, but canonical deletion belongs to the storage owner or a human
owner-approved workflow.

## Kiwix On Shared Storage

For Kiwix-specific setup and archive validation, use
`runbooks/offline-knowledge-reservoir.md`. The shared-storage model adds these
rules:

- Serve verified ZIMs from read-only canonical storage whenever possible.
- Keep download, repair, and refresh writes separate from served ZIM paths.
- Maintain `library.xml`, OPDS-visible inventory, per-archive manifests, and
  agent-friendly catalogs as promoted canonical metadata.
- Keep a tiny test ZIM on important service hosts when practical so service
  smoke tests can run even if the NAS is unavailable.

Two serving patterns are acceptable:

- A central Kiwix service owned by Mnemosyne, the NAS appliance, or another
  approved service host serves the canonical library to the trusted LAN.
- Individual agent hosts run local `kiwix-serve` instances against read-only NAS
  mounts and depend on the mount through systemd or equivalent service
  ordering.
- Separate community-library appliances consume a read-only export into local
  staging, validate it independently, and atomically promote a local release so
  field use does not depend on NAS availability.

In either pattern, do not let a local serving process become an implicit owner
of canonical archives. Refreshes remain full replacement events with staging,
checksum validation, manifest/catalog updates, smoke tests, and rollback or
retention decisions.

## Kiwix And Kolibri Split-Storage Cutover

Use different storage semantics for these services. Kiwix consumes an approved
corpus; Kolibri writes imported content while also maintaining mutable
application and facility state.

| Service data | Location | Access |
| --- | --- | --- |
| Kiwix ZIMs, `library.xml`, and promoted catalog metadata | Dedicated NAS corpus mount | Read-only to the Kiwix service identity |
| Kolibri `CONTENT_DIR` payload | Dedicated NAS content mount | Read-write to the Kolibri service identity |
| Kolibri home, live application/facility database, configuration, cache, logs, and runtime state | Suitable local storage | Read-write to the Kolibri service identity; never placed on SMB by this pattern |
| Download, repair, proposal, and backup work | Separate owner-approved namespaces | Not exposed through either serving mount |

Do not point Kolibri's whole home or data directory at SMB. Set only the
version-supported `[Paths] CONTENT_DIR` setting to the NAS content mount. Keep
the live application SQLite database, facility and learner state, job state,
configuration, cache, and logs local. Some Kolibri versions place imported
channel index files under `CONTENT_DIR`; those travel with the content payload,
but that does not justify moving the live application database or the rest of
Kolibri's home. Recheck the installed version's path layout and current
`content movedirectory` procedure before cutover.

### Separate Mount And Identity Boundary

Provision two NAS principals or equivalently isolated ACL roles, not one
general service-host account:

- the Kiwix principal can read only the promoted Kiwix corpus subtree;
- the Kolibri principal can read and write only its content payload subtree;
- neither principal can access the other service's namespace, storage-owner
  work areas, snapshots, proposals, backups, or unrelated shares.

Mount those subtrees separately and map each mount to only its service account.
The NAS ACL is the authority; client-side ownership and modes provide a second
boundary. Do not use a shared Unix group, a broad parent mount, `noperm`, or a
single credential that can reach both namespaces.

The following is a shape, not a copy-paste unit. Replace every placeholder in
host-private deployment configuration, keep authentication material outside
shared notes, and name each `.mount` unit from its `Where=` path with
`systemd-escape --path --suffix=mount`:

```ini
[Unit]
Description=<service> NAS content mount
After=network-online.target
Wants=network-online.target

[Mount]
What=//<nas-host>/<share>/<service-subdirectory>
Where=<service-mount>
Type=cifs
Options=<ro-or-rw>,_netdev,nosuid,nodev,noexec,uid=<service-user>,gid=<service-group>,forceuid,forcegid,file_mode=<file-mode>,dir_mode=<directory-mode>
TimeoutSec=30

[Install]
WantedBy=multi-user.target
```

Use `ro`, file mode `0440`, and directory mode `0550` for Kiwix. Use `rw`,
file mode `0640`, and directory mode `0750` for Kolibri content. Adjust a
support process's read access narrowly if the installed package proves it is
required; do not make either mount broadly readable to solve a service-package
integration problem.

For CIFS subdirectory mounts, prefer including the service subdirectory in the
UNC source, as shown in `What=`, when the NAS and client support it. In practice
this can be more reliable than mounting the share root and supplying the
subpath only through an option such as `prefixpath=`. If one form fails, test
the other against the same narrow server ACL; do not fall back to a broadly
accessible parent mount.

Before using the mounts, test both positive and negative access as the real
service identities:

- Kiwix can read a known ZIM and `library.xml`, but cannot create, replace, or
  remove a file on its mount.
- Kolibri can create, read, and remove a disposable probe only inside its
  content mount.
- Kiwix cannot traverse the Kolibri mount, and Kolibri cannot traverse the
  Kiwix mount.
- Each NAS principal is denied the other subtree even from a client that is not
  relying on the local Unix modes.

### Mount-Gated Services

Add a separate drop-in to each service so systemd starts the corresponding
mount first and fails closed when it is unavailable:

```ini
[Unit]
Wants=network-online.target
After=network-online.target
RequiresMountsFor=<service-mount>
ConditionPathIsMountPoint=<service-mount>
```

Use the Kiwix mount in the Kiwix drop-in and the Kolibri content mount in the
Kolibri drop-in. Inspect the effective units with `systemctl cat` and
`systemctl show`; do not assume the package's service name, user, group, or
existing dependency graph. After changing a unit or `[Paths] CONTENT_DIR`, run
`systemctl daemon-reload` and the service's configuration validation where one
exists.

With the NAS available at boot, each service should start only after its mount
is active. With the NAS unavailable, the mount attempt should time out within
the local policy, each dependent content service should remain inactive or
failed, and the rest of the host—including the operator's recovery path—should
still boot. Do not silently serve an unmounted empty directory or
automatically switch to a stale local corpus. After storage returns, start or
verify the mounts, restart the services, and repeat deep-content validation.

### Reversible Cutover

1. Record the effective service identities, local paths, mount paths, current
   Kiwix library count, selected archive IDs, Kolibri channel/resource
   inventory, and representative content checksums in a host-private change
   record.
2. Back up Kolibri's local application database and other live state. Confirm
   both local corpora are healthy before copying; a damaged source is not
   rollback data.
3. Create the two narrow server-side ACLs and mount definitions. Complete the
   positive and negative permission tests before copying content.
4. Copy Kiwix corpus data into its promoted read-only namespace and Kolibri
   content into its writable content namespace. Quiesce Kolibri for the final
   synchronization, and quiesce any Kiwix catalog mutation before its final
   synchronization.
5. Compare expected file inventories, byte sizes, and recorded checksums.
   Treat a dry-run copy comparison as extra evidence, not a substitute for
   integrity checks.
6. Point Kiwix at the mounted library and set only Kolibri
   `[Paths] CONTENT_DIR` to its mounted content. Add the mount dependencies,
   reload systemd, and start the mounts and services.
7. Run the deep validation below from the service host and from an intended LAN
   client. Also exercise NAS loss and recovery before declaring the cutover
   operational.
8. Leave the local corpus and Kolibri content copy intact but inactive until an
   operator confirms normal LAN behavior, the expected inventory, real content
   responses, and rollback readiness. Reclamation is a separate,
   explicitly-authorized operation after checksum comparison and independent
   backup review.

For rollback, stop the affected service, restore its previous local path and
unit configuration, reload systemd, start it against the preserved local copy,
and repeat the same inventory and deep-content tests. Roll back Kiwix and
Kolibri independently; a fault in one service must not require changing the
other.

### Deep-Content Validation

Homepage success proves only that a web process or proxy answered. The cutover
does not pass unless all four content checks below succeed:

1. **Kiwix OPDS inventory:** fetch `/catalog/v2/root.xml` and
   `/catalog/v2/entries?count=-1`, compare the entry count with `library.xml`,
   and assert that at least one expected archive ID is present. Follow the path
   and OPDS procedure in `runbooks/offline-knowledge-reservoir.md`.
2. **Real Kiwix archive response:** fetch a known article route from a selected
   archive, require a successful response and non-empty body, and confirm an
   expected article marker. Do not substitute the Kiwix root page.
3. **Kolibri channel inventory:** query the installed version's channel API or
   supported management command, require the expected channel ID, and compare
   its resource or node count with the pre-cutover inventory. Kolibri's
   internal API can change, so discover the route from the installed version
   rather than embedding one version's private endpoint in automation.
4. **Real Kolibri asset response:** select a known imported document,
   thumbnail, exercise, or HTML5 asset from that inventory; fetch its actual
   content URL; require a successful response, non-zero expected size or
   checksum, and the expected content type. Do not substitute the landing or
   learn page.

Repeat these checks from a client on the intended trusted LAN boundary. Then
unavailable-NAS scenario review should make checks 1 through 4 fail rather than
returning convincing but content-free homepages. After restoring the NAS,
require all four to pass again without widening either service's permissions.

## Backups And Retention

Separate agent brain backups from bulky corpora:

- Agent brain backups include durable notes, selected config, service/timer
  definitions, scripts, repo metadata, and other restore-critical state.
- Bulky corpora include ZIMs, large model artifacts, training datasets, media,
  and downloaded archive mirrors.
- For boot drives, memory drives, or removable media that may contain an agent,
  use the whole-device preservation guardrails in
  `runbooks/agent-host-responsibility.md` before destructive drive work.
- Ordinary agents may write backup output only to their assigned backup
  namespace.
- Mnemosyne owns backup promotion, retention, snapshot cadence, restore smoke
  tests, repair, and deletion for shared/canonical storage.

Backups should be encrypted where policy requires it, incrementally maintained
where practical, and periodically restore-tested. Record credential storage
locations and revocation/rotation procedures only as metadata; never store
secret values in shared notes.

For custody-host selection, trial-first validation, and the boundary between
storage ownership and accelerated local inference, use
`runbooks/storage-owner-hardware-and-inference.md`.

## Guardrails

- Do not record NAS credentials, private keys, passwords, recovery codes, mount
  secrets, Wi-Fi credentials, private addresses, hostnames, device identifiers,
  serial numbers, or local-only personal paths in shared guidance.
- Prefer read-only mounts for ordinary agents and serving layers.
- Prefer explicit write namespaces over broad group-writable shares.
- Keep canonical manifests and catalogs machine-readable.
- Keep proposal records small enough for review and rich enough to reconstruct
  provenance, validation, and promotion decisions.
- Require explicit human approval before granting a general-purpose agent write
  access outside its owned namespace.

## Scenario Review

Use this quick review before approving a shared-storage change:

- Two ordinary agents can mount the reservoir and read the same canonical ZIMs,
  manifests, catalogs, docs, and approved backups without having write access to
  canonical paths.
- One ordinary agent can stage a new corpus proposal under its owned namespace
  without affecting served content.
- Mnemosyne can validate the staged artifact, promote it into canonical
  storage, update `library.xml` and catalogs, snapshot the result, and clean up
  proposal artifacts according to policy.
- A rejected proposal leaves canonical content unchanged and produces a clear
  reason for the proposing agent or human owner.

## Related Issue Chain

- [RYA-66 - Research post-apocalypse knowledge and information access](https://linear.app/ryan-hayward/issue/RYA-66/research-post-apocalypse-knowledge-and-information-access)
- [RYA-67 - Add shared runbook for Kiwix/offline knowledge reservoir setup](https://linear.app/ryan-hayward/issue/RYA-67/add-shared-runbook-for-kiwixoffline-knowledge-reservoir-setup)
- [RYA-68 - Install Kiwix text+image reservoir on Pi 5 SSD](https://linear.app/ryan-hayward/issue/RYA-68/install-kiwix-textimage-reservoir-on-pi-5-ssd)
- [RYA-69 - Curate first-wave practical ZIM corpus for offline reservoir](https://linear.app/ryan-hayward/issue/RYA-69/curate-first-wave-practical-zim-corpus-for-offline-reservoir)
- [RYA-70 - Add provenance, integrity, and refresh workflow for offline reservoir](https://linear.app/ryan-hayward/issue/RYA-70/add-provenance-integrity-and-refresh-workflow-for-offline-reservoir)
- [RYA-71 - Expose agent-friendly offline catalog and retrieval interface](https://linear.app/ryan-hayward/issue/RYA-71/expose-agent-friendly-offline-catalog-and-retrieval-interface)
- [RYA-72 - Evaluate offline access mode: LAN service vs local hotspot](https://linear.app/ryan-hayward/issue/RYA-72/evaluate-offline-access-mode-lan-service-vs-local-hotspot)
- [RYA-73 - Plan broader offline learning stack beyond Kiwix](https://linear.app/ryan-hayward/issue/RYA-73/plan-broader-offline-learning-stack-beyond-kiwix)
- [RYA-74 - Harden Linear worker for long-running resumable downloads and network loss](https://linear.app/ryan-hayward/issue/RYA-74/harden-linear-worker-for-long-running-resumable-downloads-and-network)
- [RYA-75 - Update shared long-running Kiwix download guidance for aria2/systemd logging](https://linear.app/ryan-hayward/issue/RYA-75/update-shared-long-running-kiwix-download-guidance-for-aria2systemd)
- [RYA-77 - Document Offline Reservoir NAS/Mnemosyne shared-storage model](https://linear.app/ryan-hayward/issue/RYA-77/document-offline-reservoir-nasmnemosyne-shared-storage-model)
- [RYA-205 - Document NAS-backed Kiwix and Kolibri split-storage cutover procedure](https://linear.app/ryan-hayward/issue/RYA-205/document-nas-backed-kiwix-and-kolibri-split-storage-cutover-procedure)
