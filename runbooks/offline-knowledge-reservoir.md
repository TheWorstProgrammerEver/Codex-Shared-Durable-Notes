# Offline Knowledge Reservoir

Use this runbook when a Codex-managed Linux host needs a local, durable
knowledge library for humans and agents. Prefer a small Kiwix service first;
graduate to Internet-in-a-Box only when the host is meant to be a broader
community learning appliance.

For multi-agent NAS-backed sharing, least-privilege mounts, ordinary-agent
write namespaces, and Mnemosyne-style promotion ownership, also read
`runbooks/offline-reservoir-shared-storage.md`.

## Kiwix Or Internet-in-a-Box

Choose Kiwix when the target is:

- a managed Linux host that should keep its existing OS, SSH, systemd, and
  Codex workflow;
- a ZIM-first archive of Wikipedia, Wikimedia projects, Stack Exchange,
  manuals, books, or custom Zimit captures;
- simple LAN HTTP access through `kiwix-serve`;
- direct agent access to a local library XML file, OPDS catalog, HTTP search,
  or `python-libzim`-based reader.

Choose Internet-in-a-Box when the target is:

- a public or classroom learning hotspot;
- a curated bundle of Kiwix, OER2Go, Archive.org, maps, Kolibri, Moodle,
  Nextcloud, WordPress, or similar applications;
- an appliance-style deployment where IIAB should own more of the host
  configuration and content admin surface.

On an already-managed Codex host, do not install IIAB over the top of the host
unless the operator explicitly accepts that larger ownership boundary.

## Filesystem Layout

Use a predictable service root such as `/srv/offline-knowledge`:

```text
/srv/offline-knowledge/
  incoming/          # partial downloads, metalinks, torrents, staging
  zim/               # verified ZIM archives served by Kiwix
  manifests/         # one manifest per archive
  catalog/           # optional agent-friendly JSON or Markdown catalog
  logs/              # bounded transfer and repair logs
  state/             # durable job state and heartbeat records
  library.xml        # Kiwix XML library generated with kiwix-manage
```

Keep large downloads out of home directories and temp directories. The service
root should have enough free space for a full replacement copy during refreshes.
When the service root is NAS-backed, serve canonical ZIMs and metadata through a
read-only mount and keep download, repair, and proposal writes in separate
owned namespaces.

## Download And Validation

Treat every ZIM as an archive artifact with provenance. Prefer official Kiwix
catalog entries and official `download.kiwix.org` or mirror descriptors. Many
Kiwix downloads expose `.zim.meta4` metalink and `.zim.torrent` descriptors next
to the `.zim` file; use them when available because they include mirror and
checksum metadata and support resumable transfer tooling.

Implementation commands below are examples only; adapt paths, service users,
ports, and package sources to host policy. Example using an official metalink
descriptor:

```bash
archive=wikipedia_en_all_nopic_2026-06.zim
base=https://download.kiwix.org/zim/wikipedia

aria2c --continue=true --check-integrity=true \
  --dir=/srv/offline-knowledge/incoming \
  --follow-metalink=mem "$base/$archive.meta4"
```

For large ZIM downloads or repairs that must outlive the current Codex
session, run the transfer as a detached local job such as a systemd oneshot
service, not as foreground terminal output. The operator start command should
return immediately:

```bash
systemctl start --no-block offline-knowledge-download.service
systemctl status offline-knowledge-download.service
```

Record progress in a small state file and inspectable logs under the service
root. For `aria2c` under systemd, quiet the console explicitly and send
diagnostic output to a file:

```bash
aria2c --continue=true --check-integrity=true \
  --dir=/srv/offline-knowledge/incoming \
  --follow-metalink=mem \
  --quiet=true \
  --console-log-level=warn \
  --summary-interval=0 \
  --log=/srv/offline-knowledge/logs/$archive.aria2.log \
  --log-level=warn \
  "$base/$archive.meta4"
```

`--console-log-level=warn --summary-interval=0` is not sufficient by itself for
non-interactive systemd jobs; `aria2c` can still emit progress readouts into
the journal. Use `--quiet=true` when the journal should contain only service
start, stop, and failure information.

If a wrapper writes heartbeat records such as
`/srv/offline-knowledge/state/health.ndjson`, start the heartbeat only after
the `aria2c` child PID is captured, or make the heartbeat discover the process
from the systemd cgroup or process table. Do not start a Bash background
heartbeat before assigning the child PID and expect it to see later variable
updates; the background loop runs in a subshell.

For long-running one-shot units, keep resume and inspection separate from the
initial start:

- start with `systemctl start --no-block ...`;
- inspect with `systemctl status ...`, `journalctl -u ...`, the state file,
  and the `aria2c` log;
- resume by starting the same unit again against the same `incoming/`
  directory and descriptor;
- bound log growth with service-specific log rotation, cleanup, or conservative
  `aria2c` log levels.

After download, validate size and checksum from the descriptor or upstream
manifest before promoting the file:

```bash
sha256sum /srv/offline-knowledge/incoming/$archive
install -m 0644 /srv/offline-knowledge/incoming/$archive \
  /srv/offline-knowledge/zim/$archive
```

If a descriptor is unavailable, use `curl -C -` or another resumable downloader
against the direct URL, then record the independent checksum source used. Do not
serve an archive whose size, checksum, or provenance is unknown.

## Per-Archive Manifests

Create a small manifest beside each accepted archive. YAML or JSON is fine as
long as it is easy to parse. Include at least:

- `name`: exact ZIM filename;
- `title`: human-readable title;
- `variant`: language, topic, and `mini` / `nopic` / `maxi` where applicable;
- `source_url`: direct ZIM URL or catalog entry URL;
- `descriptor_url`: `.meta4`, `.torrent`, or null with a reason;
- `retrieved_at`: UTC date/time;
- `size_bytes`: verified file size;
- `checksum`: algorithm and digest, preferably SHA-256;
- `license`: upstream license when available;
- `provenance`: publisher, project, catalog, and any generation tool such as
  Zimit;
- `refresh_policy`: review cadence and replacement rule;
- `notes`: operational caveats, including whether the file contains media.

## Kiwix Library And Service

Install `kiwix-tools` from the host's package source or an approved upstream
release. Use `kiwix-manage` to maintain `library.xml`; avoid hand-writing XML.

Example service setup:

```bash
kiwix-manage /srv/offline-knowledge/library.xml add \
  /srv/offline-knowledge/zim/wikipedia_en_all_nopic_2026-06.zim
```

Example systemd unit shape:

```ini
[Unit]
Description=Offline knowledge Kiwix service
After=network-online.target
Wants=network-online.target

[Service]
User=kiwix
Group=kiwix
ExecStart=/usr/bin/kiwix-serve --library --monitorLibrary \
  --address=0.0.0.0 --port=8080 /srv/offline-knowledge/library.xml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Bind to localhost instead of all addresses when the content should only be
available to local agents or a reverse proxy. Use firewall policy or a private
network boundary before exposing the service beyond a trusted LAN.

## Agent-Friendly Access

Preserve the human browser UI, but expose stable machine-readable surfaces:

- local HTTP URL for browser and agent use;
- Kiwix `library.xml` for exact served-archive inventory;
- `kiwix-serve` OPDS endpoints such as `/catalog/v2/root.xml` and
  `/catalog/v2/entries?count=-1`;
- per-archive manifests in `manifests/`;
- optional generated `catalog/offline-knowledge.json` summarizing archive
  titles, variants, checksums, licenses, and local URLs;
- optional `python-libzim` reader or a small MCP/search shim for structured
  article lookup without scraping the browser UI.

Agents should prefer the catalog and OPDS metadata for inventory questions, then
use HTTP search/content or `python-libzim` for article retrieval.

## Refresh Strategy

Kiwix does not currently provide incremental ZIM updates. Plan refreshes as full
file replacement events:

- compare local manifests with the official Kiwix catalog or directory listing;
- stage new versions under `incoming/`;
- validate descriptor metadata, size, and checksum before promotion;
- keep the old archive until the new one is added to `library.xml` and served;
- leave enough disk headroom for old and new copies during the swap;
- update manifests and any agent catalog in the same change;
- reload `kiwix-serve` through `--monitorLibrary`, `SIGHUP`, or a service
  restart after `library.xml` changes;
- record the refresh date and source in durable notes or the archive manifest.

Keep a tiny test ZIM in the corpus so service rebuilds and smoke tests do not
require touching a large archive.

## Validation Checklist

- `kiwix-serve` starts under systemd and returns the library page.
- `/catalog/v2/root.xml` and `/catalog/v2/entries?count=-1` return inventory
  metadata.
- At least one article opens through HTTP for every promoted archive.
- Search works for archives that include full-text indexes.
- Every served ZIM has a manifest with source, retrieval date, variant, size,
  checksum, license, and provenance.
- Detached `aria2c` jobs do not spam progress output into `journalctl -u ...`.
- Heartbeat records include the child PID and current process state, or document
  how state is discovered independently.
- Transfer log directories stay bounded after the largest expected retry or
  repair cycle.
- No manifest or durable note contains credentials, private hostnames, private
  IP addresses, device identifiers, or local-only personal paths.

## Upstream References

- Kiwix FAQ and catalog: https://get.kiwix.org/en/faq/
- Kiwix tools and `kiwix-serve`: https://kiwix-tools.readthedocs.io/en/latest/kiwix-serve.html
- `kiwix-manage`: https://man.archlinux.org/man/kiwix-manage.1.en
- Debian `kiwix-tools`: https://packages.debian.org/sid/utils/kiwix-tools
- Official Wikipedia ZIM directory: https://download.kiwix.org/zim/wikipedia/
- Internet-in-a-Box: https://internet-in-a-box.org/
- IIAB installation: https://github.com/iiab/iiab/wiki/IIAB-Installation
- Zimit: https://github.com/openzim/zimit
- `python-libzim`: https://github.com/openzim/python-libzim
