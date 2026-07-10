# Offline Reservoir Shared Storage Model

Use this runbook when multiple local agents or approved humans need to read from
the same offline knowledge reservoir, especially when bulky archives move from a
single host disk to NAS-backed storage. Treat the Offline Reservoir as shared
local knowledge with a change process, not just a Kiwix service or a casual file
share.

Kiwix is the first serving layer. The durable system is broader: curated
corpora, provenance, refresh policy, catalogs, retrieval surfaces, backups,
snapshots, and owner-approved promotion into canonical storage.

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

In either pattern, do not let a local serving process become an implicit owner
of canonical archives. Refreshes remain full replacement events with staging,
checksum validation, manifest/catalog updates, smoke tests, and rollback or
retention decisions.

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
