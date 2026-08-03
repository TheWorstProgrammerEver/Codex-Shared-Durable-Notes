# Temporary Read-Only SMB For Removable Media

Use this flow when an operator needs short-lived Finder or other SMB browsing
of removable media attached to a managed Linux host. Treat the share as one
bounded transaction, not as permanent NAS configuration.

The safety boundary has two independent read-only layers:

1. mount the exact approved partition read-only; and
2. export only that mount through an authenticated, encrypted, read-only share.

Do not continue when either layer is unproved. Never copy a real password,
host name, address, device identifier, mount path, directory listing, or log
from this transaction into shared notes or an issue.

## Preconditions

- Confirm the media is not agent identity-bearing state that first needs the
  [agent media preservation flow](agent-host-responsibility.md#agent-media-preservation).
- Use stable whole-device and partition aliases under `/dev/disk/by-id/`, not
  enumeration order or transient names such as `/dev/sdb` and `/dev/sdb1`.
- Record the operator-approved device attributes privately: whole-device and
  partition identity, size, filesystem, and expected hardware identity.
- Choose an existing local account that can read the mounted tree but has no
  broader privilege than needed. Samba authentication maps to a Unix account;
  do not work around unreadable media by exporting it as root or remounting it
  read-write.
- Choose the exact LAN address to bind and the exact client address, or the
  narrowest approved client subnet. Do not bind a wildcard address.
- Close any existing SMB service first and prove that TCP port 445 is unused.

Examples below use the synthetic account `media-reader`, share `media`, and
the documentation-only addresses `192.0.2.10` and `192.0.2.20`. Replace every
example input with a privately reviewed value before running commands.

## Keep Distribution Services Disabled

Install only the packages needed for `smbd`, `smbpasswd`, `testparm`, and
`smbclient`. Prevent package installation from starting distribution-managed
Samba services. On a systemd-based Debian-family host, mask the relevant units
before installation, then leave them persistently masked afterward:

```bash
set -Eeuo pipefail
set +x
sudo -v
sudo systemctl mask --runtime \
  smbd.service nmbd.service samba-ad-dc.service winbind.service
sudo apt-get install --no-install-recommends samba smbclient
sudo systemctl disable --now \
  smbd.service nmbd.service samba-ad-dc.service winbind.service
sudo systemctl mask \
  smbd.service nmbd.service samba-ad-dc.service winbind.service
```

Use the distribution's equivalent no-start mechanism elsewhere. Do not
overwrite an existing package policy hook. Stop if installation starts a
daemon despite the guard. Verify every distribution unit is inactive and
masked; enabling any of them later requires a separate operator decision.

Open a dedicated root shell for the rest of the transaction and keep every
variable in that one shell. The snippets retain explicit `sudo` at privileged
boundaries, but their private-file redirections assume the controlling shell is
also root. Enter the root shell first:

```bash
sudo -i
```

Then establish fail-closed Bash behavior inside that new shell before entering
any later block:

```bash
set -Eeuo pipefail
set +x
test "$(id -u)" = 0
```

Keep this strict shell state for the entire transaction. A failed identity,
mount, configuration, permission, readiness, denial, or cleanup check must
stop the flow before the next effect. Only the expected negative probes below
handle failure explicitly or disable `errexit` for one bounded command.

## Reidentify And Mount The Partition Read-Only

These example aliases are synthetic:

```bash
DEVICE_ALIAS=/dev/disk/by-id/usb-EXAMPLE_REMOVABLE_MEDIA
MEDIA_ALIAS=/dev/disk/by-id/usb-EXAMPLE_REMOVABLE_MEDIA-part1
MOUNT_POINT=/mnt/example-media-ro

DEVICE="$(readlink -e -- "$DEVICE_ALIAS")"
PARTITION="$(readlink -e -- "$MEDIA_ALIAS")"
test -b "$DEVICE"
test -b "$PARTITION"
test "$(lsblk -dnro TYPE -- "$DEVICE")" = disk
test "$(lsblk -dnro TYPE -- "$PARTITION")" = part
PARTITION_PARENT_KNAME="$(lsblk -dnro PKNAME -- "$PARTITION")"
test -n "$PARTITION_PARENT_KNAME"
PARTITION_PARENT="$(readlink -e -- "/dev/$PARTITION_PARENT_KNAME")"
test "$PARTITION_PARENT" = "$DEVICE"

IDENTITY_COLUMNS=NAME,KNAME,PKNAME,TYPE,MAJ:MIN,SIZE,RM
IDENTITY_COLUMNS=$IDENTITY_COLUMNS,FSTYPE,MODEL,SERIAL
DEVICE_IDENTITY_JSON="$(lsblk --json --tree --bytes --paths \
  --output "$IDENTITY_COLUMNS" \
  "$DEVICE")"
test -n "$DEVICE_IDENTITY_JSON"
printf '%s\n' "$DEVICE_IDENTITY_JSON"

DEVICE_MAJ_MIN="$(lsblk -dnro MAJ:MIN -- "$DEVICE")"
PARTITION_MAJ_MIN="$(lsblk -dnro MAJ:MIN -- "$PARTITION")"
```

Querying the whole device makes its record and its partition children available
in one private topology snapshot; querying only the partition can omit the
parent record and return empty hardware fields. Privately compare the structured
output with every approved whole-device and partition attribute, including the
expected parent-child relation and the approved hardware identity. A removable
flag, kernel path, or device number alone is not identity evidence. Stop if the
approved hardware identity is unavailable or the selected partition is not a
child of the approved whole device. Do not paste the output into shared logs
because model and serial fields can identify the device.

Require an empty, unmounted target, mount with read-only and defensive options,
then inspect the effective mount rather than trusting the command request:

```bash
sudo install -d -m 0750 "$MOUNT_POINT"
! findmnt --mountpoint "$MOUNT_POINT" >/dev/null
sudo mount -o ro,nosuid,nodev,noexec -- "$PARTITION" "$MOUNT_POINT"
test "$(findmnt -nro MAJ:MIN --target "$MOUNT_POINT")" = "$PARTITION_MAJ_MIN"
findmnt -nro OPTIONS --target "$MOUNT_POINT" \
  | tr ',' '\n' \
  | grep -Fx ro
```

Stop and unmount if the effective options do not contain the exact `ro` token.
Confirm the selected Unix account can list the intended root before starting
Samba. Do not change private media contents or permissions to make this pass.

## Build Isolated Runtime State

Keep configuration, passdb, plaintext client credentials, logs, sockets, and
PID state in one operation-owned directory under `/run`. Disable shell tracing
before reading a secret and pre-authorize `sudo` so it cannot consume secret
input unexpectedly.

```bash
set +x
sudo -v
RUNTIME_ROOT="$(sudo mktemp -d -p /run temporary-media-smb.XXXXXX)"
sudo install -d -m 0700 \
  "$RUNTIME_ROOT/private" \
  "$RUNTIME_ROOT/state" \
  "$RUNTIME_ROOT/cache" \
  "$RUNTIME_ROOT/lock" \
  "$RUNTIME_ROOT/pid" \
  "$RUNTIME_ROOT/ncalrpc" \
  "$RUNTIME_ROOT/log"

SMB_CONFIG="$RUNTIME_ROOT/smb.conf"
PASSDB="$RUNTIME_ROOT/private/passdb.tdb"
AUTH_FILE="$RUNTIME_ROOT/private/smbclient.auth"
LAN_ADDRESS=192.0.2.10
CLIENT_ADDRESS=192.0.2.20
SMB_USER=media-reader
SHARE_NAME=media
```

Create a configuration that binds only the intended address, denies other
clients, requires SMB 3 encryption and authentication, and points every mutable
Samba path at the runtime directory:

```bash
sudo tee "$SMB_CONFIG" >/dev/null <<EOF
[global]
    server role = standalone server
    security = user
    map to guest = Never
    interfaces = $LAN_ADDRESS
    bind interfaces only = yes
    hosts allow = $LAN_ADDRESS $CLIENT_ADDRESS
    hosts deny = ALL
    smb ports = 445
    disable netbios = yes
    server min protocol = SMB3_00
    server smb encrypt = required
    load printers = no
    disable spoolss = yes
    printing = bsd
    printcap name = /dev/null
    dns proxy = no
    private dir = $RUNTIME_ROOT/private
    state directory = $RUNTIME_ROOT/state
    cache directory = $RUNTIME_ROOT/cache
    lock directory = $RUNTIME_ROOT/lock
    pid directory = $RUNTIME_ROOT/pid
    ncalrpc dir = $RUNTIME_ROOT/ncalrpc
    log file = $RUNTIME_ROOT/log/smbd.%m.log
    max log size = 1024
    passdb backend = tdbsam:$PASSDB

[$SHARE_NAME]
    path = $MOUNT_POINT
    browseable = yes
    read only = yes
    writeable = no
    guest ok = no
    valid users = $SMB_USER
    follow symlinks = no
EOF
sudo chmod 0600 "$SMB_CONFIG"
sudo testparm -s "$SMB_CONFIG" >/dev/null
```

Inspect `testparm -s` locally and require the effective values above. Do not
accept an unknown parameter or a value silently normalized away.

Create only the runtime Samba identity and client credential file. The account
must already exist in the local Unix account database; this does not add it to
the system Samba passdb.

```bash
read -rsp 'Temporary SMB password: ' SMB_PASSWORD
printf '\n'
{
  printf 'username = %s\n' "$SMB_USER"
  printf 'password = %s\n' "$SMB_PASSWORD"
} | sudo tee "$AUTH_FILE" >/dev/null
printf '%s\n%s\n' "$SMB_PASSWORD" "$SMB_PASSWORD" \
  | sudo smbpasswd -L -s -c "$SMB_CONFIG" -a "$SMB_USER"
unset SMB_PASSWORD
sudo chmod 0600 "$AUTH_FILE" "$PASSDB"
test "$(sudo stat -c %a "$AUTH_FILE")" = 600
test "$(sudo stat -c %a "$PASSDB")" = 600
```

Never put the password in an argument, environment variable, service property,
issue, durable note, or shared log. Keep debug logging off; Samba password-chat
debugging can expose plaintext secrets.

## Start With A Bounded Lifetime

Run only `smbd` from the isolated config in a transient service. The lifetime
is a hard backstop, not a substitute for explicit teardown:

```bash
UNIT=temporary-media-smb
sudo systemd-run \
  --unit="$UNIT" \
  --collect \
  --property=Type=simple \
  --property=RuntimeMaxSec=30m \
  --property=KillMode=control-group \
  --property=TimeoutStopSec=30s \
  /usr/sbin/smbd \
    --foreground \
    --no-process-group \
    --configfile="$SMB_CONFIG"
```

If a firewall rule is required, add only an operation-owned rule for the exact
client and TCP port 445, record its handle privately, and remove that exact rule
during cleanup. Do not open a permanent subnet-wide SMB rule for this task.

## Gate Readiness After Start Or Restart

Service state is not readiness. Use a bounded loop that requires both the exact
listening address and an authenticated listing whose client explicitly demands
encryption:

```bash
LISTING_LOG="$RUNTIME_ROOT/private/listing.log"

wait_for_encrypted_listing() {
  local deadline=$((SECONDS + 30))

  while ((SECONDS < deadline)); do
    if sudo ss -H -ltn 'sport = :445' \
         | awk -v endpoint="$LAN_ADDRESS:445" \
             '$4 == endpoint { found = 1; next }
              { unexpected = 1 }
              END { exit !found || unexpected }' \
       && sudo smbclient "//$LAN_ADDRESS/$SHARE_NAME" \
            --authentication-file="$AUTH_FILE" \
            --max-protocol=SMB3 \
            --client-protection=encrypt \
            --command='ls' >"$LISTING_LOG" 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

wait_for_encrypted_listing
sudo systemctl restart "$UNIT.service"
wait_for_encrypted_listing
```

Run the same gate after every start, restart, or configuration change. Keep the
listing log private because filenames may be sensitive. A version of
`smbclient` without `--client-protection=encrypt` is not evidence for this
procedure; stop and use a supported client.

Confirm unauthenticated access is rejected. Require both a failed command and
an authentication-denial status in its private output:

```bash
GUEST_LOG="$RUNTIME_ROOT/private/guest.log"
if sudo smbclient "//$LAN_ADDRESS/$SHARE_NAME" \
     --no-pass \
     --max-protocol=SMB3 \
     --client-protection=encrypt \
     --command='ls' >"$GUEST_LOG" 2>&1; then
  printf '%s\n' 'guest access unexpectedly succeeded' >&2
  false
fi
grep -Eq 'NT_STATUS_(ACCESS_DENIED|LOGON_FAILURE|ACCOUNT_DISABLED)' "$GUEST_LOG"
```

## Prove Writes Are Denied Without Trusting Exit Status

Use a unique ASCII basename that is absent before the probe. Some `smbclient`
write commands report an SMB error but still exit successfully, so the process
status is diagnostic only. Success requires the expected protocol denial and
independent proof that no filesystem artifact exists:

```bash
PROBE_NAME=smb-read-only-probe.txt
PROBE_SOURCE="$RUNTIME_ROOT/private/$PROBE_NAME"
WRITE_LOG="$RUNTIME_ROOT/private/write.log"
sudo test ! -e "$MOUNT_POINT/$PROBE_NAME"
printf '%s\n' 'read-only probe' | sudo tee "$PROBE_SOURCE" >/dev/null

set +e
sudo smbclient "//$LAN_ADDRESS/$SHARE_NAME" \
  --authentication-file="$AUTH_FILE" \
  --max-protocol=SMB3 \
  --client-protection=encrypt \
  --command="put $PROBE_SOURCE $PROBE_NAME" >"$WRITE_LOG" 2>&1
SMBCLIENT_WRITE_STATUS=$?
set -e

grep -Eq 'NT_STATUS_(ACCESS_DENIED|MEDIA_WRITE_PROTECTED|WRITE_PROTECTED)' \
  "$WRITE_LOG"
sudo test ! -e "$MOUNT_POINT/$PROBE_NAME"
findmnt -nro OPTIONS --target "$MOUNT_POINT" \
  | tr ',' '\n' \
  | grep -Fx ro
printf 'smbclient diagnostic exit status: %s\n' "$SMBCLIENT_WRITE_STATUS"
```

Do not relax the expected error match merely because the artifact is absent;
transport or authentication failure is not evidence that the share itself
denied a write.

## Ordered Cleanup

1. Disconnect Finder and every other client from the share.
2. Stop the transient unit. `systemctl stop` waits for the unit, and
   `KillMode=control-group` keeps child processes in the same cleanup boundary.
3. Wait until the unit is no longer active. Prove no process is listening on
   TCP port 445 before touching the mount.
4. Re-resolve both stable aliases, rebuild the whole-device topology snapshot,
   and compare it with the captured whole-device and partition identities plus
   the mounted source. If any identity changed, stop for operator reconciliation
   rather than unmounting a replacement device.
5. Unmount the exact mount and prove it is absent.
6. Remove only the exact operation-owned firewall rule, runtime directory, and
   credentials. Leave distribution Samba units masked.

```bash
if sudo systemctl is-active --quiet "$UNIT.service"; then
  sudo systemctl stop "$UNIT.service"
fi
for _ in $(seq 1 30); do
  sudo systemctl is-active --quiet "$UNIT.service" || break
  sleep 1
done
! sudo systemctl is-active --quiet "$UNIT.service"
MAIN_PID="$(sudo systemctl show --property=MainPID --value \
  "$UNIT.service" 2>/dev/null || printf 0)"
test "$MAIN_PID" = 0
! sudo ss -H -ltn 'sport = :445' | grep -q .

CLEANUP_DEVICE="$(readlink -e -- "$DEVICE_ALIAS")"
CLEANUP_PARTITION="$(readlink -e -- "$MEDIA_ALIAS")"
CLEANUP_PARENT_KNAME="$(lsblk -dnro PKNAME -- "$CLEANUP_PARTITION")"
test -n "$CLEANUP_PARENT_KNAME"
CLEANUP_PARTITION_PARENT="$(readlink -e -- "/dev/$CLEANUP_PARENT_KNAME")"
CLEANUP_DEVICE_IDENTITY_JSON="$(lsblk --json --tree --bytes --paths \
  --output "$IDENTITY_COLUMNS" \
  "$CLEANUP_DEVICE")"
CLEANUP_DEVICE_MAJ_MIN="$(lsblk -dnro MAJ:MIN -- "$CLEANUP_DEVICE")"
CLEANUP_MAJ_MIN="$(lsblk -dnro MAJ:MIN -- "$CLEANUP_PARTITION")"
test "$CLEANUP_DEVICE" = "$DEVICE"
test "$CLEANUP_PARTITION" = "$PARTITION"
test "$CLEANUP_PARTITION_PARENT" = "$CLEANUP_DEVICE"
test "$CLEANUP_DEVICE_IDENTITY_JSON" = "$DEVICE_IDENTITY_JSON"
test "$CLEANUP_DEVICE_MAJ_MIN" = "$DEVICE_MAJ_MIN"
test "$CLEANUP_MAJ_MIN" = "$PARTITION_MAJ_MIN"
test "$(findmnt -nro MAJ:MIN --target "$MOUNT_POINT")" = "$PARTITION_MAJ_MIN"
sudo umount -- "$MOUNT_POINT"
! findmnt --mountpoint "$MOUNT_POINT" >/dev/null

test "$(dirname -- "$RUNTIME_ROOT")" = /run
case "$(basename -- "$RUNTIME_ROOT")" in
  temporary-media-smb.??????) ;;
  *) printf '%s\n' 'refusing unexpected runtime path' >&2; false ;;
esac
test ! -L "$RUNTIME_ROOT"
test "$(sudo stat -c %u "$RUNTIME_ROOT")" = 0
sudo rm -rf --one-file-system -- "$RUNTIME_ROOT"
test ! -e "$RUNTIME_ROOT"

for service in smbd nmbd samba-ad-dc winbind; do
  test "$(systemctl is-enabled "$service.service" 2>/dev/null)" = masked
  ! systemctl is-active --quiet "$service.service"
done
```

If the lifetime expires first, perform the same port, identity, unmount, and
runtime-state checks. Never unmount while an SMB process or client connection
may still be using the media.

## Disposable Rehearsal Checklist

Before using private media, rehearse with synthetic names and a disposable
filesystem or mount:

- prove the stable test partition is the expected identity and is effectively
  mounted `ro`;
- validate the isolated config with `testparm` and verify both the auth file and
  passdb are mode `0600`;
- prove the listener is only on the selected address;
- prove an encrypted authenticated listing succeeds after initial start and
  after restart;
- prove guest access is rejected;
- prove a write returns an allowed SMB denial string and leaves no artifact,
  regardless of the client exit status;
- use a short `RuntimeMaxSec` once and prove automatic expiry closes the port;
- repeat with explicit teardown and prove the port is closed, the exact media
  is unmounted, runtime credentials are gone, and default services remain
  masked.

## References

- [Samba `smb.conf` parameters](https://www.samba.org/samba/docs/man/manpages/smb.conf.5.html)
- [Samba `smbclient` command](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html)
- [Samba `smbd` command](https://www.samba.org/samba/docs/current/man-html/smbd.8.html)
- [systemd transient service options](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html)
