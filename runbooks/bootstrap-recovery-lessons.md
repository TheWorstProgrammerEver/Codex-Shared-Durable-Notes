# Bootstrap Failure And Recovery Lessons

Fresh-host bootstrap should be supervised until it has succeeded on real
hardware. Dry-runs and idempotence checks are valuable, but first boot exposes
networking, image, firmware, package, and credential assumptions.

This runbook covers fresh-host and image bootstrap. When moving an established
agent identity, use
[Agent Identity Migration Between Hosts](agent-identity-migration.md) for state
classification, consistent snapshots, logical database checks, parallel
cutover, rollback, and source retirement. A setup repository or boot image may
create the clean target, but it does not replace that identity-restore process.

## Two-Phase Bootstrap

Use a simple first phase to install minimum prerequisites:

- package updates;
- git;
- runtime dependencies;
- Codex CLI;
- bootstrap skills or setup repository;
- optional SSH/tmux primitives.

Then let Codex or the setup framework complete higher-level configuration using
runbooks and skills.

## Codex Npm Runtime Path

Fixing npm's global prefix and an interactive shell's `PATH` does not prove that
a non-login service or timer can launch Codex. For the target service account:

- confirm `npm config get prefix`, `command -v codex`, and `codex --version`
  interactively;
- configure the service `PATH` with the user-owned npm global `bin` directory
  before root-owned binary directories, or set `CODEX_BIN` to the resolved
  absolute Codex executable path;
- do not rely on shell startup files or unverified `$HOME` expansion in a
  generated unit or environment file.

Exercise the same lookup with a minimal non-login environment. For example:

```bash
USER_NPM_BIN="$(npm config get prefix)/bin"
env -i PATH="${USER_NPM_BIN}:/usr/local/bin:/usr/bin:/bin" \
  sh -c 'command -v codex && codex --version'

CODEX_BIN="$(command -v codex)"
env -i CODEX_BIN="${CODEX_BIN}" PATH=/usr/bin:/bin \
  sh -c 'test -x "$CODEX_BIN" && "$CODEX_BIN" --version'
```

Run this validation as the account used by the service. If the real unit still
fails, inspect its effective environment and executable resolution rather than
assuming the interactive shell result applies.

## Image And Media Validation

When preparing removable boot media:

- verify the downloaded image checksum;
- verify the write when practical;
- run read-only filesystem checks after customization;
- keep local-only configuration out of public repos;
- document the exact image family and setup method that worked.

### Staged Multi-Root OS Customization

Keep device and mount orchestration separate from release-specific mutation.
The orchestrator owns target authorization, locking, topology rechecks, mounts,
unmounts, cleanup, and raw-image verification. The OS adapter receives already
mounted roots plus explicit filesystem capabilities and returns a complete
plan. Follow
[Agent Media Preservation](agent-host-responsibility.md#agent-media-preservation)
for destructive-media authorization, backup confirmation, identity rechecks,
and exact-write verification instead of duplicating those guardrails in each
adapter.

Treat customization as four ordered phases:

| Phase | Required result |
| --- | --- |
| Source verification | The pinned release, immutable assembly, and every source bundle entry satisfy the adapter contract without reading secret values. |
| Target preflight | One complete, ancestry-safe placement plan fits every mounted root and is compatible with each root's release state and filesystem capabilities. |
| Application | The already-approved plan is applied once, without rediscovery or per-root partial retry. |
| Postconditions | Filesystem-appropriate assertions explicitly pass and contain only allowlisted, credential-free fields. |

No target write, ownership or mode change, account edit, secret hydration, or
service mutation may occur until source verification and target preflight have
passed for every root. A failure on the last root must leave the first root
unchanged.

#### Source Verification And Complete Planning

Verify the immutable OS and artifact contracts before inspecting targets for
mutation:

- pin the OS release identity and validate every release marker the adapter
  relies on;
- validate the assembly identity, manifest, and every bundle entry, including
  its type, size, digest, and allowed relative destination;
- reject absolute paths, empty components, `.` or `..`, alternate separators,
  source symlinks, special files, duplicate destinations, and manifest/bundle
  drift;
- distinguish ordinary content, boot-consumed credential inputs, and
  runtime-staged secret references in the plan rather than passing one
  secret-bearing bundle through every phase; and
- enumerate every placement across every root, including required ancestors,
  expected existing shapes, representable metadata, and postconditions.

Resolve each destination beneath its declared root. Walk every existing path
component without following links, reject ancestry escapes and unexpected
files, directories, or links, and keep the checked root identity attached to
the placement. Do not calculate destinations again while applying the plan.

#### All-Roots Target Preflight

Preflight the complete plan against all mounted roots before applying any root:

- verify root identity, partition role, filesystem type, release/account
  compatibility, required seed files, service grammar, and all existing path
  shapes consumed by the adapter;
- reject target symlinks, incompatible collisions, ambiguous accounts or
  numeric identities, and a root whose effective capabilities differ from the
  plan;
- require explicit per-entry modes and numeric ownership only on filesystems
  that faithfully represent them; and
- model non-POSIX behavior explicitly, including mount-wide identity and masks,
  case folding, name restrictions, link support, atomicity, and sync behavior.
  An ordinary POSIX temporary directory is not proof of these semantics.

Capacity is a cross-root precondition, not an error to discover while copying.
For each root, conservatively block-round planned file allocations, reserve
per-entry allocation and metadata overhead, add bounded documented growth
slack, and check both generally available blocks and free inodes. Apparent
source bytes or total free bytes alone are insufficient. Reject the entire plan
before its first write when any root lacks capacity.

If a locked removable target is larger than the verified raw image and the
only supported recovery is to grow a filesystem, first unmount every
customization root. The device orchestrator must verify the exact final
growable partition and sufficient trailing geometry, perform only bounded
offline partition and filesystem operations, settle and revalidate the
immutable topology, remount, and rerun the complete source and all-roots
preflight. Apply once only after that repeated preflight passes. An exact-shape
target that cannot fit must remain unchanged at every planned and
credential-bearing destination.

#### Application, Secrets, And Postconditions

Apply only the verified plan and preserve its source and target identities.
Keep cleanup ownership for every mount or external operation even when an
adapter takes effect and then reports failure. Idempotent re-entry must either
prove the intended postcondition already exists or perform the same bounded
operation; it must not accept a partial cross-root plan as complete.

Boot configuration may require credential material before the target runner
exists. Keep those boot-consumed inputs separate from runtime-staged secret
sources and hydrate each only at its last responsible boundary. On a FAT-like
or other non-POSIX boot filesystem, private-looking per-file mode bits may be
fiction: mount-wide masks can restrict access from the running OS, but they do
not protect plaintext from physical-media reads. Document that at-rest boundary
and minimize the lifetime and scope of boot-consumed material.

Verify postconditions according to each filesystem's real capabilities. A
POSIX root may assert entry type, bytes, link target, numeric ownership, and
mode. A non-POSIX root may instead assert bytes, entry shape, and effective
mount-wide identity or mask behavior. Reports must contain only a closed set of
stable assertion identifiers, public placement identifiers when needed, and an
explicit `passed` status. Exclude credential values, content-derived credential
fingerprints, raw exceptions, source paths, and arbitrary target content. The
orchestrator must runtime-validate the report schema and require every expected
assertion to explicitly report `passed`; presence, truthiness, or an
adapter-level success flag is not enough.

#### Faithful Fixtures And Validation

Derive each golden root from the pinned release state needed by the adapter,
not from a convenient empty directory. Preserve every behavior the adapter
invokes: baseline or placeholder accounts and numeric identities, existing seed
files, accepted service grammar, partition roles, filesystem capabilities, and
existing directory, file, and link shapes. Reject a fixture as incomplete when
any adapter-consumed baseline element is absent. Keep unrelated release content
out only when the fixture records why the adapter cannot observe it.

Routine validation should use fixture roots, capability fakes, regular files,
and fake external adapters rather than real devices. Cover:

- the faithful golden release, an incompatible release, an incomplete golden
  fixture, account collisions, bundle drift, and idempotent re-entry;
- wrong-root or wrong-partition inputs, source and target symlink/traversal
  attacks, existing-shape conflicts, and fake mount or command failures;
- one POSIX root plus one FAT-like capability fake, including rejection of
  impossible per-entry ownership or mode claims;
- insufficient blocks, insufficient inodes, block/metadata overhead, exact-shape
  no-mutation failure, and an enlarged sparse regular-file/loop case that
  repreflights and completes;
- failed assertion status, missing or extra assertions, redaction scans, and
  cleanup scans for mounts, mappings, loop attachments, processes, temporary
  roots, and secret-bearing residue; and
- a second OS adapter with different partition labels and boot mechanisms so
  release-specific assumptions cannot masquerade as generic policy.

For example only, a pinned Raspberry Pi OS adapter may need to preserve a
release placeholder account and validate a FAT-like boot root mounted at
`/boot/firmware`. That adapter should model the boot root's effective
mount-wide identity and masks instead of pretending it supports per-file
`chown` and `chmod`. Those account, path, partition, and first-boot details are
release-specific examples, not defaults for other adapters.

Source learning:
[RYA-181 - Preflight multi-root image customization before mutation](https://linear.app/ryan-hayward/issue/RYA-181/hive-mind-preflight-multi-root-image-customization-before-mutation).

## Network First Boot

Do not assume a headless machine has network access. Validate the OS-specific
first-boot network mechanism.

For Raspberry Pi OS Lite ARM64 Trixie, cloud-init NoCloud reads first-boot
network configuration from the boot partition. A Netplan v2 `network-config`
file is the reusable shape for Wi-Fi provisioning on that image family.

## Secrets

Do not bake these into images or public repositories:

- Codex auth;
- GitHub App private keys;
- GitHub tokens;
- Linear OAuth tokens;
- API keys;
- private SSH keys;
- Wi-Fi credentials;
- initial plaintext passwords.

Use local-only configuration files, prompts, or operator handoffs, and record
only metadata in durable notes.

### Byte-Exact Image-Recipe Inputs

Treat every local secret file as a byte-level input whose format comes from the
recipe schema. Scalar account passwords, Wi-Fi passphrases, API keys, and
similar literals normally must not contain a line ending. Write them with
`printf %s`; `echo`, `printf '%s\n'`, and here-documents usually append a
newline and therefore change the credential.

For example, this GNU/Linux Bash flow assumes `secret_file` names a file in a
trusted operator-controlled directory. It prompts without echo, replaces an
existing file or symlink with a private regular file, and validates the actual
target's mode, byte count, and newline-free shape without printing the value:

```bash
umask 077
IFS= read -r -s -p 'Secret value: ' secret_value
printf '\n' >&2

expected_bytes="$(printf %s "$secret_value" | wc -c)"
if ! install -m 600 /dev/null "$secret_file"; then
  unset secret_value expected_bytes
  printf '%s\n' 'could not create private secret file' >&2
  exit 1
fi

printf %s "$secret_value" >"$secret_file"
unset secret_value

file_mode="$(stat -c '%a' -- "$secret_file")"
actual_bytes="$(wc -c <"$secret_file")"
bytes_without_line_endings="$(
  LC_ALL=C tr -d '\015\012' <"$secret_file" | wc -c
)"

if [ ! -f "$secret_file" ] ||
   [ -L "$secret_file" ] ||
   [ "$file_mode" != 600 ] ||
   [ "$actual_bytes" -ne "$expected_bytes" ] ||
   [ "$bytes_without_line_endings" -ne "$actual_bytes" ]; then
  printf '%s\n' 'secret file permissions or shape are invalid' >&2
  exit 1
fi

unset expected_bytes file_mode actual_bytes bytes_without_line_endings
```

Keep secret values out of command arguments, logs, issue comments, pull
requests, and durable notes. The validation may report only a stable result,
byte counts when operationally useful, or a generic failure; it must not print
the file contents or a content-derived fingerprint.

Do not apply the scalar newline check to structured credentials that
legitimately contain line breaks, such as PEM certificates or private keys.
Preserve those source bytes exactly and validate against their format and an
independently trusted size or digest. Avoid shell command substitution for
multiline sources because it removes trailing newlines.

When an image adapter unexpectedly reports an invalid initial account password
or passphrase, first check for a trailing carriage return or newline introduced
by the file-creation method. Recreate the local input byte-exactly and rerun
non-secret validation before retrying customization.

Source learning:
[RYA-196 - [Agent Boot] Document byte-exact secret file handling for image recipes](https://linear.app/ryan-hayward/issue/RYA-196/agent-boot-document-byte-exact-secret-file-handling-for-image-recipes).

## Recovery Signals

Bootstrap scripts and services should leave inspectable state:

- systemd unit status;
- journal logs;
- setup logs;
- durable notes or handoff files;
- clear retry commands;
- clear cleanup commands when a partial setup is safe to remove.

Prefer a failed but inspectable setup over a script that hides errors or loops
forever.
