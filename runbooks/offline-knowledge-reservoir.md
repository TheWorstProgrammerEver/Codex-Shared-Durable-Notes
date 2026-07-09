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
When relying on stable relative paths in `library.xml`, run `kiwix-manage`
mutations from the documented reservoir root and pass the library path from
that same root, such as `library.xml`. Do not invoke add/remove commands from
an arbitrary working directory and assume `--zimPathToSave=zim/...` will still
produce paths that resolve from the service's library context.

Example service setup:

```bash
cd /srv/offline-knowledge

kiwix-manage library.xml add \
  zim/wikipedia_en_all_nopic_2026-06.zim \
  --zimPathToSave=zim/wikipedia_en_all_nopic_2026-06.zim
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

## Library Path And OPDS Validation

Do not treat `kiwix-serve` startup success as proof that every archive in
`library.xml` is being served. Kiwix can load the XML while silently exposing
only entries whose `book` `path` attributes resolve to real local ZIM files.

After any `library.xml` update:

- resolve every `book` `path` from the same path context used by the service
  or from the documented library root, and confirm the target exists before
  restarting or declaring success;
- prefer stable relative paths such as `zim/<filename>.zim` when the service
  runs from the library root, and run `kiwix-manage` add/remove operations with
  that root as the working directory and `LIBRARY_PATH` context;
- after add/remove operations, inspect the saved `book` `path` values
  themselves, not only the resolved filesystem targets;
- if the host intentionally uses absolute paths or a different relative-path
  convention, document the exact `kiwix-manage` working directory,
  `LIBRARY_PATH`, and `kiwix-serve` path convention used on the host;
- restart or reload `kiwix-serve`, then compare the `library.xml` `book` count
  with `/catalog/v2/entries?count=-1`;
- explicitly check that selected or newly promoted archive IDs appear in OPDS,
  not just that OPDS returns HTTP 200;
- investigate any count mismatch or missing selected ID as a library path,
  service working-directory, permissions, or failed-promotion problem before
  moving on to article smoke tests.

Example path-resolution check for a library that should save root-relative
`zim/<filename>.zim` values:

```bash
python3 - <<'PY'
from pathlib import Path
from xml.etree import ElementTree

library = Path("/srv/offline-knowledge/library.xml")
root = library.parent
missing = []
bad_saved_paths = []

for book in ElementTree.parse(library).findall(".//book"):
    raw_path = book.get("path")
    if not raw_path:
        missing.append((book.get("id"), "<missing path>"))
        continue
    saved = Path(raw_path)
    if saved.is_absolute() or ".." in saved.parts or saved.parts[:1] != ("zim",):
        bad_saved_paths.append((book.get("id"), raw_path))
    resolved = (root / raw_path).resolve()
    if not resolved.is_file():
        missing.append((book.get("id"), raw_path))

if bad_saved_paths:
    for book_id, raw_path in bad_saved_paths:
        print(f"unexpected saved path: {book_id} -> {raw_path}")
    raise SystemExit(1)

if missing:
    for book_id, raw_path in missing:
        print(f"missing: {book_id} -> {raw_path}")
    raise SystemExit(1)

print("all library.xml book paths resolve")
PY
```

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

Agents should prefer the aggregate catalog and OPDS metadata for inventory
questions, then use a local JSON wrapper around Kiwix HTTP routes for retrieval
when that is enough.

### Catalog Plus Local Wrapper Pattern

Use this low-complexity pattern before adding another daemon:

1. Keep `kiwix-serve` as the human UI and canonical local HTTP reader.
2. Generate an aggregate catalog such as `catalog/offline-knowledge.json` from
   `library.xml`, per-archive manifests, and on-disk ZIM metadata.
3. Provide a local CLI wrapper, for example `offline-knowledge-agent`, that
   reads the aggregate catalog, calls Kiwix on `127.0.0.1`, and emits JSON with
   archive provenance, retrieval context, and the Kiwix route used.

The wrapper should have commands for at least:

- `catalog`: list archive summaries from the aggregate catalog, including
  title, filename, local URL path, checksum, source URL, retrieval and
  verification timestamps, license, provenance, refresh policy, article and
  media counts, tags, and a full-text-index flag;
- `catalog --archive <archive>`: resolve one archive by filename, title,
  library ID, library name, or URL path;
- `suggest --archive <archive> --term <term>`: call Kiwix `/suggest`, preserve
  its JSON suggestions, and add archive provenance;
- `search --archive <archive> --query <query>`: call Kiwix `/search`, parse the
  HTML result list into JSON, and report that the result came from parsed Kiwix
  search HTML;
- `article --archive <archive> --path <article_path>`: fetch the served article
  HTML from Kiwix, extract text for agent use, and include the exact local HTML
  URL for rendered tables, images, and page-specific license details.

This interface is deliberately local-first. It should not fetch external
internet resources during catalog, search, suggestion, or article retrieval
after the corpus is present.

### Retrieval Layer Tradeoffs

Distinguish the retrieval surfaces clearly:

- Aggregate catalog: best first stop for agent inventory, local provenance,
  checksums, retrieval and verification timestamps, license notes, refresh
  policy, and disk/corpus summary fields. Kiwix does not maintain these local
  operations fields for you.
- Kiwix OPDS: good for served-inventory checks and comparing `library.xml`
  counts with `/catalog/v2/entries?count=-1`; not enough by itself for local
  provenance, checksum, or freshness decisions.
- Kiwix `/suggest`: returns JSON and is useful for title completion or finding
  article paths in a specific archive.
- Kiwix `/search`: returns an HTML page. It can include useful snippets and
  article links, but any JSON wrapper has to parse Kiwix's page shape.
- Article routes: return served HTML. Text extraction is useful for agent
  context, but agents should keep the exact local URL when rendered layout,
  images, tables, or page-specific licensing matter.
- `kiwix-search`: fast local CLI search, but often returns titles only. Use it
  for quick checks when titles are enough; prefer the wrapper when paths,
  snippets, archive provenance, and JSON output matter.
- `python-libzim`: use when direct ZIM reads, richer metadata access, or a
  stable non-HTML parser justify adding a dependency.
- Small HTTP shim: use when multiple local or remote consumers need a stable
  HTTP JSON API beyond the human Kiwix UI.
- MCP server: use when MCP-native discovery, tool schemas, or cross-agent tool
  registration justify a separate process and operational surface.

Search quality depends on archive indexes. Archives tagged `_ftindex:yes`
support full-text search; archives without a full-text index may behave more
like title search or produce sparse results. Surface this flag in the aggregate
catalog or wrapper output so agents can interpret weak search results correctly.

### Agent Retrieval Validation Examples

Run these snippets in the same shell. Use neutral variables and replace the
archive and article path with a small known-good archive on the host:

```bash
agent=offline-knowledge-agent
archive=wikipedia_en_all_nopic_2026-06.zim
article=Raspberry_Pi
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

$agent catalog | python3 -m json.tool >/dev/null
$agent catalog --archive "$archive" | python3 -m json.tool >/dev/null
$agent suggest --archive "$archive" --term Raspberry --limit 1 \
  | python3 -m json.tool >/dev/null
$agent search --archive "$archive" --query "Raspberry Pi" --limit 1 \
  | python3 -m json.tool >/dev/null
$agent article --archive "$archive" --path "$article" --max-chars 1000 \
  | python3 -m json.tool >/dev/null
```

Check failure behavior returns JSON and a non-zero exit:

```bash
if $agent catalog --archive missing.zim >"$tmpdir/missing.out" 2>"$tmpdir/missing.json"; then
  echo "expected missing archive failure"
  exit 1
fi
python3 -m json.tool "$tmpdir/missing.json" >/dev/null

if $agent search --archive "$archive" --query "" >"$tmpdir/empty.out" 2>"$tmpdir/empty.json"; then
  echo "expected empty search failure"
  exit 1
fi
python3 -m json.tool "$tmpdir/empty.json" >/dev/null
```

Check that the wrapper documents local-only retrieval scope and does not require
a new listener:

```bash
$agent catalog >"$tmpdir/catalog.json"

python3 - "$tmpdir/catalog.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

interface = payload.get("context", {}).get("interface", {})
scope = " ".join(str(value) for value in interface.values())
if "127.0.0.1" not in scope:
    raise SystemExit("agent interface does not document localhost Kiwix access")
print("agent interface documents localhost Kiwix access")
PY

curl --fail --silent --output /dev/null \
  "http://127.0.0.1:8080/catalog/v2/entries?count=-1"
```

If the Kiwix service is intended to be local-agent-only, also confirm the
service binds to localhost rather than every interface. If the human UI is
intentionally LAN-visible, document that separately and keep the agent wrapper's
Kiwix calls on `127.0.0.1`.

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
- Every `library.xml` `book` path resolves to an existing ZIM from the service
  path context or documented library root.
- `/catalog/v2/root.xml` and `/catalog/v2/entries?count=-1` return inventory
  metadata, and the OPDS entry count matches the `library.xml` `book` count.
- Selected, newly promoted, or expected archive IDs are present in OPDS after
  service restart.
- At least one article opens through HTTP for every promoted archive.
- Search works for archives that include full-text indexes.
- Agent-facing catalog, suggest, search, and article commands emit valid JSON
  with archive provenance and retrieval context.
- Agent-facing failure cases emit JSON and non-zero exits for missing archives
  or invalid input.
- The agent wrapper calls local catalog files and `127.0.0.1` Kiwix routes; any
  LAN-visible human UI exposure is deliberate and documented separately.
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
