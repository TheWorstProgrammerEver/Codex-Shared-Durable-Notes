# Storage-Owner Hardware And Local Inference Rubric

Use this rubric when choosing hardware for a NAS custodian, offline-reservoir
owner, backup/restore node, or other storage-owner agent. Select the custody
host for reliable storage operations first. Treat accelerated LLM/VLM work as a
separate, measured requirement.

Do not turn an unmeasured workload into an urgent purchase. If the storage
system is about to arrive but its real bottlenecks are unknown, begin with the
trial-first phase below.

## Trial First

Start with an existing host or a portable, repurposable Pi-class node when it
can safely exercise the intended control path. Keep the pilot deliberately
constrained:

- use explicit test namespaces rather than canonical storage;
- expose allowlisted fixed operations or authenticated RPC instead of a broad
  administrative shell;
- dry-run mutations before applying them;
- begin with read-only inventory, manifests, checksums, proposal staging,
  owned-workspace creation, and backup/restore smoke tests;
- keep private filenames, manifests, ACLs, logs, policies, and corpus text
  local;
- use frontier models only for public-source research, runbook drafting,
  command review, or reasoning over adequately redacted inputs.

Do not let the pilot delete, move, rewrite permissions, configure external
sharing, or promote canonical content outside its explicit test namespaces.
Reopen the hardware decision only after the pilot identifies a measured CPU,
RAM, disk, network, backup/restore, local-model, or storage-API bottleneck.

## Primary Custody Host

Score a custody candidate on these requirements before considering accelerator
specifications:

- **Linux maturity:** supported kernel, storage, NIC, power-management, and
  monitoring paths; unattended security maintenance must be practical.
- **RAM:** enough for the operating system, filesystem cache, manifests,
  indexing, checksum jobs, and overlapping backup/restore work without swap
  pressure or out-of-memory failures.
- **Network:** sustained throughput and stable drivers appropriate to the NAS,
  backup target, and switch; headline link speed alone is insufficient.
- **Boot and service storage:** reliable NVMe or equivalent persistent storage
  for the OS, logs, job state, catalogs, and recovery tooling. Avoid fragile
  removable media as the sole control-plane disk.
- **UPS and shutdown signalling:** a tested path to observe power state, stop
  writes, persist job state, and shut down cleanly.
- **Thermal behaviour:** stable clocks, storage, and NIC behaviour during
  sustained checksum, indexing, and transfer workloads.
- **Service inspectability:** ordinary Linux processes, logs, health checks,
  restart policy, configuration, and recovery commands that an operator can
  inspect without depending on an opaque appliance UI.
- **Restore-test scratch capacity:** enough separate working space to restore
  representative data and compare it without overwriting the source or the
  only backup.

A primary custodian should also preserve permission boundaries: ordinary agents
read canonical storage and write only to owned namespaces; canonical mutation
remains an owner-approved operation.

## Custody And Inference Are Separate Decisions

Use the following default roles:

| Candidate | Default role | Choose it when | Do not assume |
| --- | --- | --- | --- |
| Existing host or Pi-class node | Constrained pilot, thin RPC host, or light custodian | Workload is unmeasured, operations are bounded, and portability or reuse matters | That it can sustain large indexes, heavy concurrency, or useful local LLM throughput |
| General-purpose x86 mini-server or workstation | Primary custody host | Mature Linux support, replaceable RAM/storage, stable networking, thermals, and recovery paths satisfy the custody rubric | That an integrated NPU or GPU makes it the right inference host |
| Jetson or similar accelerator-first edge device | Measured inference or vision companion | A tested CUDA/edge workload needs it and its memory/model constraints are acceptable | That accelerator capability compensates for weak custody, storage, RAM, or restore characteristics |
| Separate inference node | LAN inference service | Measured local tasks need more model quality, throughput, memory, or accelerator support than the custodian should carry | That it may receive every storage object or private metadata class |

An accelerator belongs in the initial custody host only when representative,
measured storage-owner tasks already prove that model execution is a primary
workload and the combined host still passes every custody requirement. Otherwise
defer the accelerator and preserve a clean split.

## Split-Inference Boundary

Run a companion inference node as a LAN-only, authenticated service with
allowlisted clients, bounded requests, explicit timeouts, and auditable request
metadata. The custodian remains authoritative for storage permissions, job
state, validation, and canonical writes; inference output is advisory until the
custodian validates it.

Define data classes before enabling the service:

1. **Custody-local:** raw filenames, manifests, ACLs, account structure,
   backup policy, private logs, private documents, and non-public corpus text.
   Keep these on the custody host unless an owner explicitly approves a local
   inference path for that class.
2. **Approved LAN inference:** minimized excerpts, derived features, or
   pseudonymous batches explicitly approved for the authenticated companion
   node. Record what crossed the boundary and avoid persistent prompt or output
   retention by default.
3. **Public or redacted external reasoning:** public vendor documentation,
   generic code and runbooks, and summaries verified to exclude private storage
   facts. Only this class may be considered for a frontier service under the
   owner's external-model policy.

Fail closed if authentication, classification, or the inference service is
unavailable. Storage operations should continue through deterministic,
runbook-governed paths or stop safely rather than silently forwarding data or
granting the inference node storage authority.

## Validation Before A Purchase

Run every test on representative, non-canonical test data. Record the dataset
size, concurrency, duration, peak RAM, elapsed time, temperatures or throttling,
network throughput, failures, and recovery steps. Define acceptable completion
time and resource headroom before the run.

- [ ] **Small LLM metadata task:** generate or normalize bounded metadata from
      sample manifests; spot-check accuracy, privacy handling, latency, and
      peak RAM.
- [ ] **Embedding and search task:** build and query a local index over
      representative catalog and manifest chunks; measure build time, query
      latency, recall on known queries, and incremental-update cost.
- [ ] **Reservoir metadata normalization:** normalize a representative mixed
      metadata set; compare counts, identifiers, checksums, provenance, and
      rejected records against expected results.
- [ ] **Sustained checksum and indexing workload:** run long enough over a
      large read-only test tree to expose thermal, disk, NIC, memory, and
      restart problems; verify resumability after interruption.
- [ ] **Backup and restore smoke test:** back up representative files and
      metadata, restore into separate scratch space, and compare checksums,
      permissions, catalog state, and documented recovery time.

Classify each failed target by bottleneck. Buy or upgrade custody hardware for
proven custody, network, memory, storage, thermal, or restore failures. Consider
an inference companion only when the LLM, embedding, or model-quality target
fails while the custody host otherwise remains reliable. A faster model demo is
not evidence that the storage control plane needs an accelerator.

## Recommendation Freshness

Immediately before recommending or purchasing hardware, recheck current vendor
documentation, Linux support, memory and storage limits, regional price, stock,
warranty, and required accessories. SBC, RAM, accelerator, and mini-server
pricing and availability change quickly; preserve the decision rubric and
validation evidence, not a stale product ranking.

## Scenario Review

A future agent should reach these outcomes without relying on a product name:

- choose an existing or Pi-class host for a constrained, repurposable pilot
  when bottlenecks are unmeasured;
- choose a general-purpose x86 host when sustained custody, RAM, networking,
  boot storage, UPS behaviour, inspectability, and restore tests require it;
- choose a Jetson-class device only for a measured accelerator-first companion
  workload, not by default as the storage custodian;
- choose a separate authenticated LAN inference node when model throughput,
  quality, or memory is the measured gap, while preserving custody-local data
  classes and storage authority on the custody host.

## Source

- [RYA-96 - Research Mnemosyne hardware for NAS custody and local AI sovereignty](https://linear.app/ryan-hayward/issue/RYA-96/research-mnemosyne-hardware-for-nas-custody-and-local-ai-sovereignty)
- [RYA-98 - Add shared rubric for storage-owner hardware and local inference split](https://linear.app/ryan-hayward/issue/RYA-98/add-shared-rubric-for-storage-owner-hardware-and-local-inference-split)
