# Offline Agent And Developer Support Pack

Use this runbook to build a small, portable set of documentation, package
artifacts, catalogs, and recovery helpers for agents and developers who may
need to work without internet access. Start with a curated static pack whose
contents and supported platforms are explicit. A support pack is not an
ecosystem mirror, a transparent package proxy, or a model/container registry.

Keep the support pack in its own root or storage namespace. Do not mix package
binaries with Kiwix ZIMs or the general static document library. Use
`runbooks/offline-knowledge-reservoir.md` for the broader content and service
rubric, `runbooks/offline-static-document-library.md` when documents need a
read-only HTTP catalog, and `runbooks/offline-reservoir-shared-storage.md` for
multi-agent proposal, promotion, NAS, and canonical-write boundaries.

## Choose The Smallest Layer

| Layer | Use It When | Required Boundary |
| --- | --- | --- |
| Curated static support pack | A bounded set of known tools, projects, platforms, and recovery tasks needs deterministic offline files. This is the default first layer. | Version, checksum, license, catalog, validate, refresh, and prune every advertised item. Copying the pack must not require a running cache service. |
| Warmed package-cache service | Several LAN clients repeatedly request a wider or changing package set and a cache miss may use the internet. Examples include `apt-cacher-ng`, `devpi-server`, and Verdaccio. | Open a separate service/storage issue covering network exposure, authentication, upstream policy, cache eviction, backup, monitoring, and offline behavior. A warmed cache is not a complete offline pack unless its required closure is exported and validated independently. |
| Full mirror or registry | The operator has accepted ecosystem-scale storage, synchronization, freshness, licensing, and recovery ownership. | Treat this as a NAS or dedicated appliance decision. Do not place full OS, Python, npm, container, model, or language-registry mirrors on a small agent host by default. |

Do not introduce a daemon merely to serve a first pack. Local files, a
machine-readable catalog, and a small validation helper are easier to inspect,
copy, restore, and remove. Escalate only after observed multi-client demand
justifies the operational surface.

## Host-Neutral Layout

Use a root selected by deployment configuration, represented here as
`<support-pack-root>`:

```text
<support-pack-root>/
  README.md
  docs/
    os-admin/
    python/
    node/
    reservoir/
    runtimes/
    projects/
  packages/
    python/
      wheels/
    node/
      tarballs/
  catalog/
    support-pack.json
  manifests/
    artifacts.json
  sources/
    licenses/
    retrieval-recipes/
  bin/
    support-pack
  validation/               # optional location for bounded reports/fixtures
```

- `docs/` contains human-readable, redistributable snapshots. Preserve the
  upstream title, version or revision, source URL, license, and retrieval time
  in the manifest rather than encoding local host facts in the document.
- `packages/` contains immutable wheels, source distributions only when
  explicitly supported, and npm tarballs. Separate incompatible platform or
  architecture closures when a package is not portable.
- `catalog/` is the quick inventory for humans and agents. It should identify
  supported tasks, platforms, local paths, freshness state, and validation
  state without requiring a package manager.
- `manifests/` is the integrity and lifecycle source of truth. It may be one
  aggregate JSON document or one document per artifact, but it must have a
  versioned schema and stable artifact IDs.
- `sources/` holds small license texts, retrieval recipes, and provenance
  evidence needed to rebuild the pack. It is not an unbounded source mirror or
  mutable download staging area.
- `bin/` contains local catalog, checksum, or validation helpers. Helpers must
  work from the configured root and must not assume a personal home directory,
  hostname, private address, or live internet connection.
- `validation/` is optional as a directory, not as a process. If reports are
  stored elsewhere, record their time, target platform, command, and result in
  the manifest or catalog.

Use a separate staging root for downloads and pack assembly. Promote a complete
validated generation into `<support-pack-root>` atomically or through the
shared-storage promotion workflow; do not download directly over the active
pack.

## First-Wave Contents

Keep the first manifest intentionally small and tied to concrete recovery or
development tasks:

- operating-system and administration runbooks needed to inspect disks,
  networking, services, logs, backups, and recovery;
- Python packaging documentation plus a wheelhouse for a short list of
  approved distributions and their complete target-platform dependency
  closures;
- Node.js and npm documentation plus a short list of npm tarballs and their
  complete dependency and platform closures;
- local Offline Reservoir catalog/CLI documentation and usage examples;
- runtime and model-management documentation, without copying model blobs or a
  model registry into the pack;
- snapshots of critical project READMEs and recovery/build instructions at
  known revisions.

Prefer official documentation archives, project release artifacts, and package
manager outputs that can be pinned and checksummed. Do not include an artifact
only because it might be useful. Each item needs an owner-visible use case,
license/provenance record, refresh rule, offline command or read path, and a
validation result.

## Manifest Contract

Use UTC timestamps and content-relative paths. At minimum, every artifact
record must contain:

- stable `id`, `kind`, `name`, `version`, and `path`;
- `source_url` and, when useful, a source revision or release URL;
- `checksum` with algorithm and digest;
- `license` with an SPDX identifier when known, otherwise an explicit review
  note and evidence path;
- `retrieved_at`;
- declared `target_platforms`, or `["any"]` for portable content;
- an `offline_use` command or read path and the capability it advertises;
- package `closure` records for required, optional, and platform-specific
  dependencies;
- `refresh` cadence, next review or maximum age, replacement rule, and
  behavior when stale;
- `prune` rule covering superseded, unsupported, revoked, or invalid content;
- `validation` time, target platform, command, result, and advertised
  capability check.

Example aggregate JSON shape:

```json
{
  "schema_version": 1,
  "pack_id": "developer-support-pack",
  "generated_at": "2030-01-15T10:00:00Z",
  "artifacts": [
    {
      "id": "python-example-tool-1.2.3-linux-arm64",
      "kind": "python-wheel-set",
      "name": "example-tool",
      "version": "1.2.3",
      "path": "packages/python/wheels/linux-arm64/example_tool-1.2.3-py3-none-any.whl",
      "source_url": "https://packages.example.org/project/example-tool/1.2.3/",
      "checksum": {
        "algorithm": "sha256",
        "value": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      },
      "license": {
        "spdx": "MIT",
        "evidence_path": "sources/licenses/example-tool.txt"
      },
      "retrieved_at": "2030-01-14T08:30:00Z",
      "target_platforms": [
        "linux-arm64"
      ],
      "offline_use": {
        "capability": "example-tool CLI starts and reports version 1.2.3",
        "command": "python3 -m pip install --no-index --find-links <support-pack-root>/packages/python/wheels/linux-arm64 example-tool==1.2.3"
      },
      "closure": {
        "required_artifact_ids": [
          "python-example-dependency-4.5.6-linux-arm64"
        ],
        "optional_artifact_ids": [],
        "platform_artifact_ids": []
      },
      "refresh": {
        "cadence": "quarterly",
        "review_after": "2030-04-14T08:30:00Z",
        "replacement": "stage and validate a complete new wheel set before promotion",
        "when_stale": "retain as last-known pack data but mark stale and do not advertise as current"
      },
      "prune": {
        "policy": "remove after a validated replacement and rollback window; remove immediately if revoked or integrity-invalid"
      },
      "validation": [
        {
          "validated_at": "2030-01-15T09:15:00Z",
          "target_platform": "linux-arm64",
          "command": "install into a new virtual environment with network disabled, then run example-tool --version",
          "result": "pass"
        }
      ]
    }
  ]
}
```

The example digest and package are placeholders. A real manifest must record
every file in a dependency closure, not only the top-level package. The
aggregate catalog may summarize this data, but it must link back to the exact
manifest IDs and must not claim a capability whose latest validation is absent,
failed, or stale.

## Package Capture Rules

For Python, generate a wheelhouse for each declared interpreter/platform
combination. Prefer wheels. If a source distribution is unavoidable, the pack
must also include and validate the offline build-system and native dependency
requirements; otherwise omit it. A successful download or checksum is not
evidence that `pip` can resolve and install the set offline.

For npm, retain the top-level tarball plus required, optional, and
platform-specific dependencies needed by every declared target. Be especially
careful with packages whose command-line binary is supplied by an optional
architecture package. A direct tarball install can succeed while the
advertised binary remains unusable. Capture the platform closure and exercise
the binary, or omit that package and capability from the pack.

Do not describe a partially warmed package-manager cache as a deterministic
closure. If a build relies on cache state, export the required artifacts into
the static pack, manifest them, and run the same isolated validation as any
other pack generation.

## Validation Gate

Run validation from an isolated temporary directory with outbound network
access disabled or otherwise proven unavailable. Start with an empty package
manager cache so a host-global cache cannot mask missing artifacts.

Before promotion:

1. Verify the recorded checksum of every file and reject unmanifested package
   binaries.
2. Parse every JSON catalog and manifest with a standard JSON parser, validate
   schema/version fields, and confirm every referenced relative path exists
   under the pack root.
3. Open representative documentation through the advertised offline read path
   and confirm critical runbooks and project snapshots are discoverable.
4. For every advertised Python package capability on every declared target,
   create a clean virtual environment, run `pip --no-index --find-links`
   against only the pack wheelhouse, then exercise the advertised import or
   CLI and verify its version or expected behavior.
5. For every advertised npm package capability on every declared target,
   install from the local tarball path with an empty cache and no network,
   include its complete dependency/platform closure, then execute the
   advertised binary or API. Installing the tarball without exercising the
   capability is a failure.
6. Run the existing Kiwix/library, static-document, or shared-storage health
   checks from the linked runbooks when the pack catalog links to those
   services. Do not duplicate those service checklists in the pack.
7. Record per-artifact, per-platform results. Omit or quarantine an artifact
   when its closure or capability fails; do not publish the rest of the pack as
   though that artifact were usable.

At least one real Python offline install is required when the pack advertises
Python packages, and at least one direct local npm tarball install is required
when it advertises npm packages. These minimums do not replace the requirement
to validate every advertised package capability and its complete closure.

## Refresh And Pruning

Every generation needs an explicit review date. A calendar cadence such as
monthly, quarterly, or before each recovery image release is not enough on its
own; record what happens when the date passes.

Use this lifecycle:

1. Inventory the active generation and mark overdue artifacts `stale` in the
   proposed catalog before considering replacement. Stale content may remain
   available as last-known data, but it must not silently appear current.
2. Retrieve replacements into separate staging, re-check license and source
   provenance, regenerate dependency closures, and compute fresh checksums.
3. Validate the complete proposed generation on every declared target. Keep
   the active generation unchanged on any failure.
4. Promote manifests, catalogs, docs, packages, and helpers as one auditable
   generation. Retain the previous known-good generation for a defined
   rollback window when storage permits.
5. Prune superseded generations after the rollback window. Remove revoked,
   compromised, checksum-invalid, unsupported, or license-incompatible
   artifacts immediately from the advertised catalog and quarantine or delete
   them according to operator policy.
6. Remove manifest and catalog references in the same change as their files.
   Check for orphaned files, broken references, and newly unsupported
   capabilities after pruning.

Set storage ceilings for the active generation, staging headroom, rollback
copy, and bounded validation reports. Crossing those ceilings triggers
curation or a separate NAS/appliance decision, not silent growth into a mirror.

## Scenario Review

- Small agent host: the pack is a bounded static directory, no package proxy is
  required, platform-specific binaries fit within a declared ceiling, and
  full mirrors/model registries remain out of scope.
- Multi-agent LAN: clients can read or copy the same validated generation;
  repeated cache-miss demand may justify a separately designed
  `apt-cacher-ng`, `devpi-server`, or Verdaccio service without changing the
  static pack's integrity boundary.
- NAS or appliance: canonical generations, staging, promotion, snapshots, and
  pruning follow `runbooks/offline-reservoir-shared-storage.md`; broad mirrors
  or registries require their own capacity, synchronization, and ownership
  decision.

## Related Issues

- [RYA-86 - Build offline agent and developer support pack plan](https://linear.app/ryan-hayward/issue/RYA-86/build-offline-agent-and-developer-support-pack-plan)
- [RYA-91 - Update shared offline reservoir guidance with developer support-pack pattern](https://linear.app/ryan-hayward/issue/RYA-91/update-shared-offline-reservoir-guidance-with-developer-support-pack)
