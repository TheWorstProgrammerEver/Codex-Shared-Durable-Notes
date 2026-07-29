# Offline Community-Library Appliance

Use this runbook when people need an offline library that supplies its own
Wi-Fi network, captive-portal entry point, dashboard, and multiple local
learning services. Keep this role on a separate image and device.

Do not install Internet-in-a-Box (IIAB), offspot, Kiwix Hotspot, or equivalent
AP/DHCP/DNS/firewall automation over a Codex-managed host. A managed host should
remain LAN-only unless a separate issue approves a tested alternate management
and recovery path.

For a Kiwix-first LAN service, use
`runbooks/offline-knowledge-reservoir.md`. For canonical NAS permissions and
Mnemosyne-style promotion, use
`runbooks/offline-reservoir-shared-storage.md`.

## Separate-Appliance Boundary

The community-library appliance owns its client network and local presentation
layer:

- Wi-Fi access point and regulatory-domain configuration;
- DHCP leases and local DNS;
- captive-portal detection responses and HTTP redirect behavior;
- port 80 dashboard, reverse proxy, and generated static home page;
- Kiwix, Kolibri, and read-only static-document routes;
- explicit admin access, update, backup, logging, and recovery policy.

The appliance must not depend on a Codex-managed host for DHCP, DNS, firewall
rules, service supervision, or boot recovery. It may consume an approved
read-only content export from a reservoir owner, but it must not gain write
authority over canonical storage merely because it can sync from it.

Upstream internet, forwarding, and NAT are off by default. Enable gateway mode
only after an operator approves the security, filtering, bandwidth, update, and
support consequences. Offline clients should still receive a useful dashboard
when no upstream network exists.

## Architecture Choices

| Path | Use It For | Boundary And Tradeoff |
| --- | --- | --- |
| IIAB on separate media | A fast pilot or reference for a broad, established community-learning stack with network modes, content administration, and many optional apps. | IIAB expects substantial OS, networking, and application ownership. Accept that model only on a dedicated appliance. Treat it as a reference architecture or fallback pilot, not something to layer onto a Codex-managed host. |
| offspot/Kiwix Hotspot pattern | A reference for a small base image, AP runtime, DNS/DHCP, captive portal, reverse proxy, dashboard, static generated home page, downloadable readers/ZIMs, and repeatable image-building. | Borrow the patterns without assuming its current image is the required hardware baseline. Its documented fixed target list should be checked before every hardware choice; as reviewed in July 2026, it did not name Raspberry Pi 5. |
| Custom appliance image | The preferred fit when the goal is an owner-controlled reservoir corpus plus Kiwix, Kolibri, static docs, explicit ports, and a smaller service surface. | The team owns image builds, upgrades, migrations, service tests, client compatibility, and recovery. This extra ownership buys a narrow, auditable appliance aligned with the existing manifest/catalog and NAS promotion model. |
| NAS-backed content sync | A source-of-truth and refresh pipeline where a storage owner promotes canonical content and appliances consume an export. | This complements rather than replaces an appliance image. Copy content locally for field use; serve directly from a NAS only in kiosk deployments where NAS availability is part of the operating contract. |

Current IIAB documentation supports Raspberry Pi 4/5-class deployments using
64-bit Raspberry Pi OS and documents multiple network ownership modes. Current
Kolibri documentation includes Raspberry Pi 5 and an offline-capable server
path. Treat these as planning inputs, not proof that a combined image works:
pin an OS release, confirm `arm64` package/container availability, and test the
exact image on the selected hardware.

## Service And Port Contract

Record the final bindings in deployment configuration and the generated
operator page. This is the default contract:

| Port Or Surface | Owner And Binding | Default Policy |
| --- | --- | --- |
| Wi-Fi AP | Appliance radio on the client network | Enabled only on the appliance; set regulatory domain and operator-provided AP settings at first boot. |
| DHCP (`67/udp`) | Appliance client-network interface | Serve only the appliance client network; never answer on an upstream or management interface. |
| DNS (`53/udp` and `53/tcp`) | Appliance client-network interface | Resolve approved local service names and captive-portal probes; do not require upstream DNS for local use. |
| HTTP dashboard (`80/tcp`) | Appliance client-network interface | Primary entry point for the dashboard, captive-portal redirects, service routes, static docs, and downloads. |
| HTTPS (`443/tcp`) | Unassigned unless separately designed | Do not intercept HTTPS. Add TLS only with an explicit certificate, name, client-trust, and renewal model. |
| Kiwix (`<kiwix-port>/tcp`) | Loopback or an internal service network | Choose and document one non-conflicting port, commonly `8080`; expose it through the port 80 reverse proxy rather than as an undocumented client endpoint. |
| Kolibri (`<kolibri-port>/tcp`) | Loopback or an internal service network | Choose and document a port distinct from Kiwix, such as `8090`, and expose it through the reverse proxy. Preserve Kolibri application state separately from immutable content. |
| Static documents | Port 80 web root or internal static service | Read-only canonical content; mutable uploads belong in a separate authenticated staging namespace. |
| SSH/admin (`22/tcp` if used) | Explicit management interface or first-boot state | Disabled by default, or enabled only after credential rotation and an approved admin-network policy. Never inherit another host's credentials or access assumptions. |
| Forwarding/NAT | Appliance firewall | Off by default. Do not make the appliance a client gateway without explicit approval and validation. |

Bind internal app ports to loopback or a private service network when the
reverse proxy is the supported entry point. Keep the dashboard useful over
plain HTTP because captive portals cannot reliably intercept HTTPS or HSTS
destinations.

## Content Contract

Treat the appliance as a consumer of a validated release:

```text
<reservoir-source>/
  zim/
  library.xml
  manifests/
  catalog/
  docs/
  kolibri-exports/

<appliance-content-root>/
  releases/
    <release-id>/
  staging/
    <release-id>/
  current -> releases/<release-id>
  reports/
```

The source may be an approved USB export, a local copied export, or a read-only
NAS export. The placeholders belong in shared guidance; deployment-specific
paths and mount details belong in local configuration.

Use this promotion flow:

1. Create a unique `<release-id>` staging directory on the same filesystem as
   `releases/`, and confirm enough space for the incoming release plus rollback
   headroom.
2. Copy from `<reservoir-source>` with staged `rsync` or an equivalent resumable
   copy. Use archive semantics and partial-transfer support, but do not mutate
   the source.
3. Validate every declared checksum, reject undeclared or missing artifacts,
   parse manifests and catalogs, verify `library.xml` paths, and compare the
   expected ZIM inventory with a Kiwix/OPDS smoke test.
4. Validate representative static documents and an exported Kolibri channel
   or resource before promotion. Keep Kolibri facility/user state outside the
   immutable content release.
5. Move the validated staging directory into `releases/` and atomically switch
   the `current` pointer on the same filesystem. Never copy directly over the
   served release.
6. Reload Kiwix, regenerate or reload the dashboard, run route checks, and keep
   the prior release until rollback and retention policy allow removal.
7. Write a validation report containing release ID, catalog counts, checksums,
   timestamps, and pass/fail results. Do not include credentials, private
   topology, or device identifiers.

An implementation may use a shape like this after replacing every placeholder:

```bash
rsync -a --partial --delay-updates \
  "<reservoir-source>/" \
  "<appliance-content-root>/staging/<release-id>/"
```

Do not use a destructive mirror option until the staging target has been
resolved and validated as a release-specific directory. An interrupted or
rejected import remains outside `current` and cannot partially replace served
content.

For NAS-backed operation, Mnemosyne or another approved storage-owner workflow
validates and promotes canonical content. The appliance receives read-only
access to an export, stages a local copy, validates it again, and promotes only
its local release. It does not write back to canonical NAS paths.

## Image And Runtime Model

Prefer a reproducible 64-bit base-image build with:

- a minimal supported OS pinned for each image release;
- a separate data partition or filesystem with refresh headroom;
- systemd supervision for AP/runtime, reverse proxy/dashboard, Kiwix, Kolibri,
  content import, validation, and bounded log cleanup;
- host packages for Kiwix and Kolibri when supported, adding containers only
  for a justified app with a verified architecture and update path;
- a generated static home page based on promoted manifests/catalogs;
- an image manifest containing source revision, package/image versions, and
  expected partition layout;
- a hardware validation matrix rather than an assumption that a compatible
  base OS proves AP, storage, or thermal reliability.

Borrow offspot's separation between a small base image, boot-time network
runtime, and packaged content/apps. Borrow its dashboard, captive-portal,
download, and image-builder workflow. Do not copy public/default credentials or
assume support for hardware outside its documented fixed targets.

Use IIAB to compare expected network modes, content administration, service
catalog, and field-operator UX. If a custom pilot cannot meet those needs
reliably, use IIAB on separate media as the fallback pilot rather than widening
the managed-host boundary.

## Operations

First boot:

- expand or initialize the data filesystem and verify free space;
- rotate all image/default credentials and require operator-provided admin and
  AP credential material without recording values in shared notes;
- set locale, timezone, Wi-Fi regulatory domain, AP display name, and optional
  upstream update policy;
- generate the dashboard from the current release and start only the selected
  services;
- run AP, DHCP, DNS, dashboard, Kiwix, Kolibri, and static-content checks;
- record image and content release IDs in a local status page.

Updates and refresh:

- define an OS/package/image update cadence and refresh before field deployment
  while connected to a trusted update source;
- refresh fast-changing content more often than stable reference packs;
- treat Kiwix ZIM changes as full validated replacement events;
- use explicit Kolibri channel export/import workflows instead of hidden online
  mutation during field use;
- preserve the previous known-good image and content release for rollback.

Backup and export:

- back up image configuration, service manifests, dashboard configuration,
  content catalogs/manifests, validation reports, and selected app settings;
- export Kolibri facility/application state according to its supported process;
- treat bulky content as a separately checksummed export or reproducible release;
- periodically restore the small configuration backup and smoke-test a content
  export.

Power-loss recovery:

- use journaling filesystems and atomic release promotion;
- keep normal serving paths read-only;
- configure service restart ordering and bounded logs;
- validate the current release and core routes after an unexpected shutdown;
- leave incomplete staging releases unserved and resumable or safely removable.

## Scenario Review

Separate appliance with local content:

- A newly imaged appliance boots without changing any managed host.
- A validated USB or copied `<reservoir-source>` imports into staging, passes
  checksum/catalog/service checks, and atomically becomes `current`.
- A client joins the AP, receives appliance DHCP/DNS, sees the captive-portal
  dashboard, and can use Kiwix, Kolibri, and static docs without internet.
- Reboot and abrupt-power-loss tests preserve the last known-good release.

NAS-backed source:

- Ordinary agents and the appliance cannot write canonical NAS content.
- Mnemosyne or an approved storage owner validates and promotes a canonical
  release, then exposes a read-only export.
- The appliance copies that export into local staging, validates it
  independently, and atomically promotes its local release.
- Loss of NAS access during community use does not affect a field appliance
  serving a completed local copy. A NAS-dependent kiosk reports the dependency
  clearly and fails without corrupting canonical or local content.

Across both scenarios, test representative Android, iOS, macOS, Windows, and
Linux clients for AP join, portal prompt, dashboard routing, Kiwix
article/search, Kolibri resources, static downloads, no-internet UX, concurrent
use, reboot persistence, and admin isolation.

## Guardrails

- Keep all AP, DHCP, DNS, captive portal, firewall, and multi-service hotspot
  behavior off Codex-managed hosts by default.
- Do not record credentials, passphrases, private keys, private addresses,
  private hostnames, mount secrets, device identifiers, serial numbers, or
  local-only paths in shared notes, manifests, validation reports, or Linear.
- Keep canonical content read-only to the appliance and ordinary agents.
- Require operator approval for NAT/gateway mode, new externally bound ports,
  mutable collaboration services, or remote administration.
- Treat actual-hardware and representative-client tests as release gates.

## Related Guidance And Issues

- [RYA-72 - Evaluate offline access mode: LAN service vs local hotspot](https://linear.app/ryan-hayward/issue/RYA-72/evaluate-offline-access-mode-lan-service-vs-local-hotspot)
- [RYA-77 - Document Offline Reservoir NAS/Mnemosyne shared-storage model](https://linear.app/ryan-hayward/issue/RYA-77/document-offline-reservoir-nasmnemosyne-shared-storage-model)
- [RYA-87 - Design separate community-library appliance image](https://linear.app/ryan-hayward/issue/RYA-87/design-separate-community-library-appliance-image)
- `runbooks/offline-knowledge-reservoir.md`
- `runbooks/offline-reservoir-shared-storage.md`
- `runbooks/offline-static-document-library.md`

## Upstream References

- IIAB platforms:
  https://github.com/iiab/iiab/wiki/IIAB-Platforms
- IIAB Raspberry Pi images:
  https://github.com/iiab/iiab/wiki/Raspberry-Pi-Images-~-Summary
- IIAB networking:
  https://github.com/iiab/iiab/wiki/IIAB-Networking
- offspot overview:
  https://github.com/offspot/overview
- offspot base image and fixed target list:
  https://github.com/offspot/base-image
- Kiwix serving:
  https://kiwix-tools.readthedocs.io/en/latest/kiwix-serve.html
- Kolibri on Raspberry Pi:
  https://kolibri.readthedocs.io/en/latest/install/raspberry_pi.html
