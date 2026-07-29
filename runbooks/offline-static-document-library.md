# Offline Static Document Library

Use this runbook for EPUB, PDF, text, manual, and local-document corpora that
need predictable browse/download access but do not belong in ZIM archives.
Start with read-only static HTTP and a machine-readable catalog. Add a mutable
service only when a concrete workflow justifies its state, authentication,
backup, and update costs.

This pattern complements `runbooks/offline-knowledge-reservoir.md`. It does not
replace Kiwix for ZIM content or
`runbooks/offline-reservoir-shared-storage.md` for multi-agent proposal and
promotion ownership.

## Choose The Smallest Service That Fits

| Need | Preferred layer | Escalate when |
| --- | --- | --- |
| Browse or download approved files by stable URL, with basic provenance and tags | Static HTTP plus HTML and JSON catalogs | Do not escalate while files and catalog metadata remain sufficient. |
| Ebook-specific metadata editing, OPDS, search, conversion, or device workflows | `calibre-server` backed by a deliberately managed Calibre library | Ebook volume or user workflow makes the additional database, import, upgrade, and backup surface worthwhile. |
| Controlled human or agent uploads | Authenticated, quota-limited WebDAV **staging** outside the served canonical tree | A named owner, review policy, cleanup policy, and promotion operation exist. WebDAV never becomes canonical merely because an upload succeeded. |
| Sync, sharing, comments, office workflows, or multi-user collaboration | Nextcloud-style service on a separately accepted application or appliance boundary | The operator accepts database, authentication, TLS/domain, update, backup, and recovery ownership. |

Static HTTP is the default baseline because the service account needs no write
permission, the corpus is inspectable as ordinary files, the service has no
upload surface, and humans and agents can use the same stable URLs. It is not a
search engine, ebook manager, collaboration suite, or authorization boundary.
Keep sensitive or access-controlled documents out of the published tree.

## Host-Neutral Layout And Ownership

Use a predictable root; `/srv/offline-library` is an example, not a required
host path:

```text
<library-root>/
  approved/                    # canonical, owner-promoted content
    public/                    # only tree exposed by static HTTP
      index.html
      files/
        <approved-file>
      catalog/
        offline-library.json
        offline-library.schema.json
    manifests/                 # optional unserved source/verification records
  staging/                     # optional future upload/proposal namespace
  state/                       # service or promotion state, not web-served
```

Enforce these boundaries:

- the HTTP service account can read `approved/public` and cannot write it;
- the HTTP service root is exactly `approved/public`, never `<library-root>`;
- only the promotion owner can replace canonical files, catalog, or schema;
- `staging` is a sibling of `approved`, never a directory beneath `public`;
- any WebDAV account writes only to `staging` and cannot promote into
  `approved`;
- promotion validates source, license, filename, checksum, and catalog entry,
  then copies or atomically moves an accepted artifact into `approved`;
- rejection or cleanup in `staging` cannot delete canonical content.

On shared storage, use separate mounts or access-control rules when ordinary
filesystem permissions do not make the boundary clear enough. Follow the
owner-approved proposal and promotion model in
`runbooks/offline-reservoir-shared-storage.md`.

## Catalog Contract

Publish the aggregate catalog at a stable service-relative path such as
`/catalog/offline-library.json`, and publish its JSON Schema beside it. Keep
service-relative URLs in the catalog so it remains valid when the host address,
port, or reverse-proxy name changes.

Each item must contain:

- `title`: human-readable title;
- `filename`: exact basename under `files/`;
- `format`: normalized file type such as `epub`, `pdf`, or `txt`;
- `source_url`: upstream artifact URL, source page, or stable `local:` provenance
  URI for an approved locally authored document;
- `license`: license identifier or a precise rights statement;
- `checksum`: an object with `algorithm: "sha256"` and the lowercase digest;
- `retrieved_at`: UTC RFC 3339 timestamp;
- `tags`: an array of short searchable strings;
- `local_url`: service-relative URL beginning with `/files/`.

Useful optional fields include `source_page_url`, `license_url`, `size_bytes`,
`provenance`, `refresh_policy`, and `notes`. Do not put credentials, private
hostnames, private addresses, personal paths, or access tokens in catalog
metadata.

Minimal item shape:

```json
{
  "title": "Example Manual",
  "filename": "example-manual.pdf",
  "format": "pdf",
  "source_url": "https://docs.example.org/example-manual.pdf",
  "license": "CC-BY-4.0",
  "checksum": {
    "algorithm": "sha256",
    "value": "<64-lowercase-hex-digest>"
  },
  "retrieved_at": "2030-01-02T03:04:05Z",
  "tags": ["manual", "example"],
  "local_url": "/files/example-manual.pdf"
}
```

Treat the catalog, schema, and approved file as one promotion unit. Generate
the next catalog in a non-served work directory, validate it, install the file,
and replace the catalog atomically. Do not publish a catalog entry before its
file is present.

## Static Service Baseline

Before installation:

1. Confirm the chosen static server package or runtime is installed from an
   approved source.
2. Confirm a dedicated unprivileged account is available.
3. Confirm the intended port is unused and does not overlap Kiwix or another
   local service.
4. Confirm the service can bind only to the intended interface: localhost for
   local-agent use, or a trusted LAN interface when humans need LAN access.
5. Confirm firewall policy does not expose the port to public or untrusted
   networks.

Example preflight, with deployment-specific values supplied by the operator:

```bash
library_root=/srv/offline-library
library_port=8090

command -v python3
getent passwd offline-library
test -d "$library_root/approved/public"
test -r "$library_root/approved/public/catalog/offline-library.json"
if ss -ltnH "sport = :$library_port" | grep -q .; then
  echo "chosen port is already in use" >&2
  exit 1
fi
```

Python's standard-library static server can be an acceptable trusted-LAN
baseline when the host already maintains Python. An existing approved Nginx,
Apache, or Caddy deployment is also suitable. In every case, allow only static
`GET` and `HEAD` behavior, disable write methods and dynamic handlers, run
unprivileged, and root the service at `approved/public`.

Example systemd unit shape:

```ini
[Unit]
Description=Offline static document library
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=offline-library
Group=offline-library
WorkingDirectory=/srv/offline-library/approved/public
ExecStart=/usr/bin/python3 -m http.server 8090 --bind 0.0.0.0 --directory /srv/offline-library/approved/public
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadOnlyPaths=/srv/offline-library/approved/public
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictRealtime=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
SystemCallFilter=@system-service

[Install]
WantedBy=multi-user.target
```

Replace the example path, port, and bind address to match the deployment.
Binding to `0.0.0.0` is only appropriate when firewall and network policy
deliberately permit trusted-LAN access. Validate the unit with
`systemd-analyze verify`, then enable it only after catalog and checksum checks
pass.

## Catalog And Checksum Validation

Validate JSON syntax against the published schema with a trusted JSON Schema
tool when one is already available. Whether or not that optional dependency is
present, verify required fields, service-relative paths, basenames, file
presence, and SHA-256 values before promotion.

This standard-library check assumes the catalog shape contains an `items`
array:

```bash
library_root=/srv/offline-library

python3 - "$library_root" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
public = root / "approved" / "public"
catalog_path = public / "catalog" / "offline-library.json"
required = {
    "title", "filename", "format", "source_url", "license",
    "checksum", "retrieved_at", "tags", "local_url",
}

catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
for position, item in enumerate(catalog["items"]):
    missing = required - item.keys()
    if missing:
        raise SystemExit(f"item {position}: missing {sorted(missing)}")

    filename = item["filename"]
    if Path(filename).name != filename:
        raise SystemExit(f"item {position}: filename is not a basename")
    if item["local_url"] != f"/files/{filename}":
        raise SystemExit(f"item {position}: local_url does not match filename")

    checksum = item["checksum"]
    digest = checksum.get("value", "")
    if checksum.get("algorithm") != "sha256" or not re.fullmatch(
        r"[0-9a-f]{64}", digest
    ):
        raise SystemExit(f"item {position}: invalid SHA-256 metadata")

    artifact = public / "files" / filename
    if not artifact.is_file():
        raise SystemExit(f"item {position}: approved file is missing")
    actual = hashlib.sha256(artifact.read_bytes()).hexdigest()
    if actual != digest:
        raise SystemExit(f"item {position}: checksum mismatch")

print(f"validated {len(catalog['items'])} catalog items")
PY
```

For very large documents, implement the same check with streamed reads rather
than `read_bytes()`. Reject path traversal, duplicate filenames or local URLs,
unknown checksum algorithms, empty license/source fields, and catalog entries
whose files are absent.

## Retrieval And Isolation Validation

After starting the service, validate in increasing scope:

1. Local: retrieve `/`, the catalog, schema, and at least one file through
   `127.0.0.1`.
2. LAN: repeat catalog and representative file retrieval from a trusted client
   using a placeholder such as `http://<library-host>:<library-port>/`; do not
   record the real private address in shared notes.
3. Isolated client: prove a client with no default route or public-internet path
   can retrieve the catalog and file.
4. Coexistence: verify both the static library and Kiwix endpoints still answer
   on distinct ports.

Example local checks:

```bash
library_port=8090

systemctl is-active offline-library.service
curl --fail --silent --output /dev/null "http://127.0.0.1:$library_port/"
curl --fail --silent --output /dev/null \
  "http://127.0.0.1:$library_port/catalog/offline-library.json"
curl --fail --silent --head \
  "http://127.0.0.1:$library_port/files/<approved-file>"
```

On Linux, a temporary network namespace and direct veth pair provide a
repeatable isolated-client check without giving the client a default route.
Use documentation-only TEST-NET addresses and remove the namespace afterward:

```bash
namespace=offline-library-check
host_link=offline-library-host
client_link=offline-library-client
library_port=8090

cleanup() {
  ip netns del "$namespace" 2>/dev/null || true
  ip link del "$host_link" 2>/dev/null || true
}
trap cleanup EXIT

ip netns add "$namespace"
ip link add "$host_link" type veth peer name "$client_link"
ip link set "$client_link" netns "$namespace"
ip address add 192.0.2.1/30 dev "$host_link"
ip link set "$host_link" up
ip netns exec "$namespace" ip link set lo up
ip netns exec "$namespace" ip address add 192.0.2.2/30 dev "$client_link"
ip netns exec "$namespace" ip link set "$client_link" up

if ip netns exec "$namespace" ip route get 1.1.1.1 >/dev/null 2>&1; then
  echo "isolated client unexpectedly has a public route" >&2
  exit 1
fi
ip netns exec "$namespace" curl --fail --silent --output /dev/null \
  "http://192.0.2.1:$library_port/catalog/offline-library.json"
ip netns exec "$namespace" curl --fail --silent --output /dev/null \
  "http://192.0.2.1:$library_port/files/<approved-file>"
```

Run this test only on a host where the operator permits temporary network
namespaces and veth interfaces. A separate client on an isolated test network
is equivalent if its routing state proves there is no public route.

Before assigning the library port, inspect the active Kiwix unit and listening
sockets rather than assuming its port. Afterward, test both services:

```bash
systemctl cat kiwix.service
ss -ltnp
curl --fail --silent --output /dev/null \
  "http://127.0.0.1:<kiwix-port>/catalog/v2/root.xml"
curl --fail --silent --output /dev/null \
  "http://127.0.0.1:<library-port>/catalog/offline-library.json"
```

## Scenario Review

Before declaring the baseline complete, walk through all three paths:

- **Static baseline:** an operator promotes one checksummed PDF; its catalog
  entry and service-relative URL validate; the service account cannot modify
  it; local, trusted-LAN, and isolated-client retrieval succeed.
- **Future WebDAV staging:** an approved user uploads a candidate to `staging`;
  the static service cannot see it; it is not cataloged or canonical until the
  promotion owner validates and copies it into `approved`.
- **Calibre escalation:** ebook-specific search, metadata editing, conversion,
  OPDS, or device workflows become a real requirement; the owner plans Calibre
  database/library backups, import behavior, service permissions, upgrades,
  ports, and migration without turning WebDAV staging into the Calibre
  canonical library.

Do not add WebDAV or Calibre merely in anticipation of possible future use.

## Rollback

Rollback should remove exposure while preserving recoverable approved content:

1. disable and stop only the static-library unit;
2. remove only firewall or reverse-proxy rules created for that service;
3. remove the unit file and reload systemd if the deployment is being retired;
4. retain or move `approved`, catalogs, schemas, and manifests to protected
   archival storage until the owner explicitly authorizes deletion;
5. handle `staging` separately according to its owner and retention policy;
6. remove the service account only after confirming no remaining file or
   service ownership depends on it.

For a bad content promotion, stop or temporarily withdraw the affected URL,
restore the previous approved file and catalog as one unit, rerun catalog and
checksum validation, then restart and repeat retrieval checks. Rollback must
not silently delete the only copy of a document or collapse staging and
canonical ownership into one writable tree.

## Shared-Note Redaction Check

Before committing shared guidance or catalog examples, scan the changed files
for:

- private IPv4/IPv6 addresses and private DNS or mDNS hostnames;
- user home directories, device identifiers, and host-only filesystem paths;
- credentials, authorization headers, tokens, passwords, key blocks, or
  credential-file locations;
- source URLs containing signed query parameters or embedded credentials.

Use `<library-host>`, `<library-port>`, `<kiwix-port>`, and similar placeholders
where a real deployment value is not necessary. Documentation ranges such as
`192.0.2.0/24` are acceptable only when clearly used for an isolated example.

## Source Learning

This baseline generalizes the implementation and validation findings from
[RYA-85 - Pilot LAN-only document and ebook library baseline](https://linear.app/ryan-hayward/issue/RYA-85/pilot-lan-only-document-and-ebook-library-baseline).
