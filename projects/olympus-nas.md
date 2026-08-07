# Olympus NAS Deployment Baseline

Olympus is the deployed household and agent-fleet storage substrate. It is a
UGREEN NASync DH4300 Plus appliance running UGOS Pro. This note identifies the
concrete appliance and its authority boundary; use the
[Offline Reservoir Shared Storage Model](../runbooks/offline-reservoir-shared-storage.md)
for the authoritative proposal, promotion, retention, backup, and recovery
workflow.

## Stable Architecture

- Olympus has four 4 TB drives in RAID 5, providing roughly 12 TB of usable
  capacity. The array's single-drive redundancy is not an independent backup.
- The Offline Reservoir currently stores its bulky Kiwix corpus and Kolibri
  channel payload on Olympus. Kiwix consumes promoted content through a
  read-only mount. Kolibri has one narrowly scoped writer for channel content,
  while its live SQLite database and other application state remain on the
  serving host.
- Canonical data reaches Olympus through staged, checksummed promotion. Service
  mounts must fail closed so an unavailable mount cannot become an apparently
  valid empty local directory.

## Authority Boundary

- Ryan retains administrative and recovery authority. Mnemosyne is the planned
  storage custodian for canonical promotion, retention, backup, restore,
  repair, indexing, and deletion.
- Ordinary agents and services receive separate NAS identities with only the
  narrow read-only or single-writer access their role requires. A successful
  mount or read does not grant ownership of canonical data.
- Agents must not assume broad write or deletion rights, Docker access, NAS
  administration, permission-management authority, or access to unrelated
  shares. Any expansion requires explicit owner approval and validation using
  the intended identity.

## Live Verification Points

Treat mutable administrative state as live evidence, not as timeless shared
knowledge. Before relying on it for an operation, verify the installed
firmware, pool filesystem, quotas, account and ACL grants, mount health, and
current backup and restore-test status through an owner-approved management
path. Keep credentials, private network details, device identifiers, private
paths, and per-agent secret material out of shared notes.

## Related Context

- [Agent Profiles](../agents/README.md) defines Mnemosyne's fleet role.
- [RYA-235 - Share the Olympus NAS deployment baseline across agents](https://linear.app/ryan-hayward/issue/RYA-235/hive-mind-share-the-olympus-nas-deployment-baseline-across-agents)
