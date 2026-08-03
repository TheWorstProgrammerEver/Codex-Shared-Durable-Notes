# Agent Host Responsibility

Dedicated local agent hosts should be boring, inspectable, and recoverable.
Prefer plain files, systemd, SSH, tmux, git, and Markdown over opaque background
state.

## Principles

- Keep the host understandable from the filesystem and standard operating-system
  tools.
- Use durable notes for continuity across sessions.
- Keep root-level pointers such as `AGENTS.md`, `CODEX_TODO.md`, and
  `REMOTE_ACCESS.md` small and discoverable.
- Prefer systemd services and timers for recurring work.
- Use tmux or an equivalent persistent terminal for long-lived interactive
  sessions.
- Keep credentials scoped and revocable.
- Prefer GitHub Apps or similarly narrow app credentials over personal access
  tokens for repository automation.
- Avoid baking OAuth tokens, API keys, private SSH keys, or other secrets into
  images, repos, or shared durable notes.

## State Boundaries

Store local operational state under predictable local paths, and document only
metadata in durable notes:

- what the state is for;
- where it lives;
- which service owns it;
- how to stop, inspect, rotate, or delete it.

Do not turn inboxes, temp directories, logs, or one-off task outputs into
durable memory by accident. Promote only facts that will help future agents.

## Agent Media Preservation

Treat agent boot drives, memory drives, and removable media that may contain an
agent as durable identity-bearing state until proven otherwise. Before
formatting, imaging, repartitioning, reusing, or otherwise destructively
changing that media:

- identify the likely agent name from physical labels, mounted volume names,
  durable notes, manifests, or the human operator;
- create a whole-device backup image when partitions or filesystems may not be
  fully readable from the current host OS;
- write backup metadata and checksums next to the image;
- store the backup under an agent-named path in the approved backup target;
- confirm the backup exists and its checksum verifies before running
  destructive format, restore, or image-write helpers.

A mounted-file copy is not a substitute for a drive-level preservation image
when the media may contain Linux root filesystems, boot partitions, service
state, durable notes, or other agent memory. Mounted-file copies can be useful
as a readable convenience artifact, but they may miss filesystems the current
host cannot mount.

When preserved or non-agent media needs short-lived human browsing, use the
[temporary removable-media SMB runbook](temporary-removable-media-smb.md) for
an authenticated, encrypted, read-only transaction. Temporary network access
does not replace the preservation decision above.

Prefer physical drive labels that include the agent name, and mirror that name
in backup paths, manifests, and restore notes. Use the NAS or storage-owner
model in `runbooks/offline-reservoir-shared-storage.md` for regular backup
cadence, retention, and promotion into shared storage; keep one-off
preservation work under an explicit approved backup target until that owner
workflow exists.

For backup and restore helper scripts:

- refuse internal system, boot, recovery, firmware-adjacent, and other
  protected host disks through non-bypassable guardrails;
- require explicit backup confirmation before destructive format or image-write
  work;
- re-verify source and destination mount identity immediately before writing,
  especially when using paths that may disappear if an external destination is
  unmounted;
- write from inside the verified destination mount or use another equivalent
  guard so a missing external mount cannot fall through to internal storage;
- make dry-run output show the selected source, destination, backup path, image
  size, and any size mismatch or larger-destination warning;
- warn operators that source volumes may be intentionally unmounted during raw
  imaging and that this does not mean the source media is safe to remove.

For restore helpers, select backup directories by normalized timestamps, require
both the raw image and checksum manifest, verify the checksum before destructive
writes, refuse restoring onto the disk that contains the backup source, and use
a mounted destination volume only as an identity anchor for resolving the whole
destination disk.

### Reuse Formatting And Sanitization Claims

Before changing preserved media, record whether the requested outcome is
deployment-ready reuse or verified sanitization. Preserve and verify the backup
first as required above. Then apply the stable-target authorization, locked
identity rechecks, exact-write accounting, and cleanup contract in
[RYA-174](https://linear.app/ryan-hayward/issue/RYA-174/hive-mind-add-fail-closed-destructive-device-guardrail-guidance).
Those controls are prerequisites for destructive work, but do not by themselves
prove that prior data was sanitized.

Keep these claims distinct:

- **Formatting** creates a partition table or filesystem, usually by replacing
  only metadata. A clean filesystem plus a successful
  mount/write/read/delete/check probe proves deployment readiness, not erasure
  of prior bytes.
- **Full overwrite** writes an explicit pattern across a documented
  host-addressable whole-device range. Call it complete only when exact byte
  counts match the revalidated device size, writes are flushed, the required
  read-back or tool verification passes, and userspace plus kernel/device logs
  show no transport or I/O failure during the operation.
- **Cryptographic or device-native erase** uses a supported media mechanism.
  Record why the mechanism applies, its documented coverage and completion
  semantics, and the status or verification evidence required by the vendor or
  approved sanitization standard. A command name or exit status alone is not
  proof.
- **Verified sanitization** is the evidence-backed outcome of an approved
  technique, not a synonym for any command above. Claim it only when the
  operation proves exact whole-device coverage or the supported native
  mechanism's documented semantics, completes without disqualifying errors, and
  satisfies the chosen verification policy. State narrower coverage explicitly
  when the method addresses only the host-visible range.

For sustained destructive writes, review kernel and device transport events
over the same interval as the writer; do not rely only on its final exit status.
A reset, timeout, disconnect, or write error leaves sanitization unproven even
when a utility retries or eventually exits zero. Stop repeated high-rate
attempts through that unstable path, preserve the verified backup and incident
evidence, and use a separately validated cable, port, or transport, or a
supported device-native erase mechanism. Report the narrower achieved outcome,
such as deployment-ready formatting, until sanitization is proved.

Use this scenario boundary when recording results:

| Evidence | Permitted outcome |
| --- | --- |
| Quick format followed by a clean filesystem check and ordinary write/read probe | Deployment-ready; sanitization unproven |
| Complete zero overwrite with exact whole-device counts, flush, required verification, and no userspace or kernel/device errors | Sanitization verified for the documented overwrite scope and policy |
| Supported native or cryptographic erase with applicable documented semantics and successful completion evidence | Sanitization verified for the documented mechanism and policy |
| Mid-write transport reset, even if the writer retries and exits zero | Sanitization unproven |
| Userspace write error after a partial overwrite | Sanitization unproven |
| Post-format mount and write validation without whole-device erase evidence | Deployment-ready; sanitization unproven |

Align organizational sanitization claims with an approved standard such as
[NIST SP 800-88 Rev. 2](https://csrc.nist.gov/pubs/sp/800/88/r2/final) and the
media-specific mechanisms it recognizes.

## Human Operator Access

For headless machines:

- document SSH host/user details in a local-only access note;
- preserve a tested attach command for the persistent agent session;
- disable password SSH after public-key access is confirmed, when policy allows;
- keep emergency recovery steps visible and current.

## Failure Bias

When automation fails, prefer recoverable partial progress:

- write status to a file or service log;
- leave clear next steps in durable notes;
- avoid destructive cleanup unless the operator asked for it;
- do not hide failure inside a long-running daemon.
