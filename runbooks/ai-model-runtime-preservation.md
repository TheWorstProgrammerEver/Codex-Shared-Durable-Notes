# AI Model And Runtime Preservation

Use this runbook when preserving downloadable AI models, their execution
runtimes, or continuity material for a closed provider. A weight file or model
manager cache is not a restorable offline capability. Preserve the exact model,
licence, dependency, runtime, platform, test, and backup evidence as one
auditable collection.

Keep the generic mechanics canonical elsewhere:

- use the coding-style skill's
  [immutable artifact acquisition](https://github.com/TheWorstProgrammerEver/codex-skills/blob/main/coding-style/references/immutable-artifact-acquisition.md)
  rules for pinning, resumable transfer, whole-file verification, quarantine,
  and atomic promotion;
- use its
  [packaged runtime verification](https://github.com/TheWorstProgrammerEver/codex-skills/blob/main/coding-style/references/packaged-runtime-verification.md)
  rules for source archives, extracted trees, executable identity, placement,
  and target-compatible service tests;
- use its
  [pinned artifact fixture conformance](https://github.com/TheWorstProgrammerEver/codex-skills/blob/main/coding-style/references/automated-testing.md#pinned-external-artifact-fixture-conformance)
  gate when manifest locks, metadata from exact verified bytes, and small
  semantic fixtures must agree; and
- use the Offline Reservoir
  [shared-storage model](offline-reservoir-shared-storage.md) for proposal,
  canonical-write, snapshot, retention, and restore ownership.

This runbook composes those controls for AI artifacts. It does not weaken or
fork their acquisition, runtime, or storage procedures.

## Classify Sovereignty And Offline State Separately

Assign each catalog entry one sovereignty class. Apply the class to the exact
artifact or variant, not merely its provider or model family.

| Class | Meaning | Preservable result |
| --- | --- | --- |
| S0: service-dependent | No lawfully downloadable weights are available; a provider control plane is required. | A continuity dossier and local-substitute mapping, never a claim that weights were archived. |
| S1: licence-restricted local | Local execution is technically possible, but gated, custom, non-commercial, proprietary, or other restrictive terms apply. | The exact accepted release and evidence of its terms, with access and use constrained accordingly. |
| S2: open-weight operational | Downloadable weights have at least one preservable open runtime, but the training flow need not be reproducible. | Original weights, attributable derivatives, runtime closure, and tests. |
| S3: substantially open model flow | Weights, code, and substantial training data, mixture, checkpoints, or evaluation material are available. | The practical reproducibility flow within an explicit capacity and retention budget. |

Open weights do not imply open source, reproducible training, permission to
redistribute, or permission for every intended use. Conversely, technical
downloadability does not establish licence rights. Record both the technical
state and exact terms for every component.

`OFFLINE-VERIFIED` is a separate operational state. Award it only to a specific
model revision, runtime revision, dependency closure, and target platform tuple
after the no-network restore gate below passes. An S3 artifact can remain
offline-unverified; an S1 artifact can pass the technical gate while retaining
its licence restrictions.

## Preserve A Complete Capability

For downloadable models, preserve this unit:

> immutable original model representation + exact licence and model card +
> tokenizer/configuration and modality dependencies + runtime/package closure
> + platform compatibility + provenance and checksums + offline fixtures and
> tests + an independently restorable copy

Start with a small lifeboat tier that supplies at least one rights-cleared,
realistically runnable capability for each required modality. Validate text,
vision, image generation, speech recognition, speech synthesis, audio, video,
or embedding paths that the collection actually claims. Acquire strategic or
multi-terabyte models only after the canonical, staging, replacement, and
independent-backup byte budgets have been approved. Size alone and popularity
do not justify displacing a verified lifeboat.

## Separate Custody Classes

Use role-based roots chosen by deployment configuration:

```text
<ai-preservation-root>/
  canonical/
    upstream/        # immutable original representations
    derived/         # independently attributable conversions
    runtimes/        # source, packages, installers, and OCI artifacts
    manifests/
    fixtures/
  staging/
  quarantine/
  caches/            # replaceable compute-local or application caches
  private/           # separately encrypted and narrowly authorized material
```

- `canonical/upstream/` is the read-only source of truth. Preserve the original
  upstream repository representation before converting it.
- `canonical/derived/` holds GGUF, MLX, ONNX, CTranslate2, quantized, pruned, or
  other conversions. Every derivative has its own identity and replay evidence.
- `caches/` is replaceable. An Ollama blob store, LM Studio cache, package cache,
  or inference host's local copy must never be the sole canonical representation.
- `private/` is not a broadly readable model archive. Keep provider exports,
  reference voices, prompt histories, fine-tuning data, and private adapters
  encrypted and under separate authorization.

Third-party quantizations can be useful derivatives, but their publisher,
source digest, conversion claim, and independent validation must be recorded.
Do not substitute their popularity or filename for the immutable upstream
original.

## Minimum Manifest Contract

Use a versioned machine-readable schema and content-relative paths. Give every
model, runtime, dependency, derivative, fixture, and continuity dossier a
stable artifact ID. At minimum record:

| Area | Required fields |
| --- | --- |
| Identity and classification | Schema version; stable artifact ID; artifact kind and role; model family and exact variant; sovereignty class; collection tier; canonical or derived status. |
| Immutable upstream | Publisher and repository; immutable full revision or release identity; resolved commit digest where applicable; source URLs; retrieval time; original filename or relative path; representation/format; every file's exact byte length, digest algorithm, and collision-resistant digest. |
| Repository completeness | Full pinned repository revision; submodule commits; Git LFS object identities and verified payload files, not pointer files; required branches or refs only when an immutable commit cannot represent necessary release evidence. |
| Licence evidence | One record per component or variant, including weights, code, tokenizer, configuration, dataset, voice, adapter, and runtime; exact licence name/version; captured text or evidence path and digest; source; review/acceptance time; material use, distribution, attribution, or access constraints. Do not record acquisition credentials or private account details. |
| Model dependencies | Required tokenizer, vocabulary, sentencepiece data, encoder, VAE, scheduler, control model, phonemizer, voice, font, codec, custom node, and remote/custom code artifact IDs; exact versions or commits; required/optional role; licence record; file identities. |
| Provenance | Acquisition recipe and trusted checksum source; source artifact IDs; model card and documentation identities; security or revocation state; SBOM references where produced. A source URL alone is not provenance or identity. |
| Derivation | Parent artifact IDs and source digests; conversion tool repository and exact commit; reviewed command with secrets and private paths excluded; dependency/environment identity; output format; quantization or conversion parameters; every output length and digest; replay and semantic-test results. |
| Runtime and packages | Runtime source/release identity; source archive and extracted-tree identities; interpreter/compiler/build-tool versions; lockfiles; complete wheels, sdists, Conda, OS, Node, or other offline package artifact IDs; installers; runtime licence records. |
| OCI and platform matrix | Image index and platform-specific manifest/config/layer digests for every required OS/architecture; target OS and architecture; CPU/GPU backend; accelerator and memory constraints; minimum/maximum tested driver, firmware, CUDA, ROCm, Metal, Vulkan, or other host compatibility. A container does not contain or prove the host kernel, firmware, GPU driver, or container runtime. |
| Tests and offline state | Rights-cleared fixture IDs, lengths, and digests; tested model/runtime/platform tuple; commands or workflow ID; network-denial and observation method; clean-cache evidence; expected semantic result; time and result; detected external requests; validator version. |
| Lifecycle and custody | Retention tier; refresh/review date; supersession, revocation, quarantine, and pruning policy; canonical relative locator; backup set and independent failure-domain locator by non-secret role; copy verification time; last restore-test time and result. |

The aggregate catalog may summarize these records, but it must link to their
exact manifest IDs. A mutable branch, moving tag, container tag, model-manager
name, local path, or successful online launch cannot be the artifact identity.
This includes a mutable Hugging Face branch, even when its current files happen
to match a previously downloaded cache.

## Intake And Supply-Chain Boundary

Before acquisition, resolve mutable discovery to an immutable contract. Pin
the entire model repository revision and enumerate every expected payload. For
Git-backed releases, fetch and verify required Git LFS objects; a repository
clone containing only LFS pointers is incomplete. For OCI content, copy the
index and every required platform manifest, config, and layer by digest rather
than trusting a mutable tag or the platform selected by the acquisition host.

Use the linked immutable-acquisition procedure for interrupted multi-file
downloads. Bind each retained partial to the exact manifest and content
identity. Verify every completed file's length and digest from byte zero before
promotion; one good shard does not authenticate the set. Quarantine corrupt,
oversized, unexpected, or identity-mismatched material.

Treat model formats and adjacent code as untrusted input:

- prefer Safetensors or another non-executable, bounded format when an
  authoritative upstream representation is available;
- quarantine pickle-backed and unknown formats for isolated inspection; do not
  deserialize them during intake merely to discover metadata;
- default to no remote code, and never execute unreviewed repository code,
  custom nodes, notebooks, conversion scripts, or plugins during acquisition;
- review and pin unavoidable custom code separately, including submodules and
  generated files; and
- keep gated-download tokens, cookies, credentials, private source URLs, and
  account details out of manifests, catalogs, commands, logs, Linear, and
  shared notes.

A licence change in a new variant or release does not rewrite the captured
terms for an older immutable artifact. Review each new component and variant,
and restrict or reject it independently.

## Runtime And Platform Closure

Retain at least one preservable runtime for every lifeboat model. Archive the
exact runtime source and release, build inputs, offline package closure,
conversion tools, configuration, launch commands, and target-platform evidence.
Use the linked packaged-runtime procedure to verify archive, extracted-tree,
entrypoint, placement, and final-path identities independently.

Do not treat a live virtual environment, installed application, LM Studio
installation, container, or package-manager cache as closure. Preserve actual
package payloads plus locks and validate installation from an empty cache.
Record host dependencies separately: a GPU container normally relies on the
host kernel, firmware, device nodes, driver, and container runtime. A passing
CPU test does not validate a GPU tuple, and one OCI architecture does not
validate another.

For workflow systems such as ComfyUI, preserve the exported workflow plus
every referenced core/custom-node commit, model, encoder, VAE, plugin, Python
package, font, and codec. A workflow JSON without that graph is documentation,
not a restorable runtime.

## Preservation Workflow

Use this order for each proposed generation:

1. **Stage:** acquire immutable upstream artifacts, licences, documentation,
   dependencies, runtimes, package closures, and fixtures into an owned staging
   namespace.
2. **Verify:** match every expected file length and digest; prove repository,
   LFS, submodule, OCI-platform, package, and dependency completeness; inspect
   unsafe formats and code without granting access to secrets or canonical data.
3. **Test:** build or install from the staged closure and execute the claimed
   model/runtime/platform tuples with the network gate below.
4. **Promote:** move only the verified generation through the shared-storage
   owner's atomic or auditable promotion path into read-only canonical custody.
5. **Catalog:** publish exact manifest IDs, legal/technical restrictions,
   capabilities, test state, and known gaps. Do not advertise a failed or stale
   tuple as offline-verified.
6. **Replicate:** copy canonical artifacts, manifests, fixtures, and recovery
   tooling to an independently governed failure domain and verify every copy.
7. **Restore-test:** restore from that independent copy into clean scratch or a
   clean target, repeat the no-network capability test, and record the result.

RAID, snapshots on the same storage system, and redundant local cache copies
improve availability but are not independent backups. Do not claim completed
preservation until the independent restore test passes. Keep the last known-good
generation until its replacement has passed the same gates and rollback window.

## No-Network Offline Verification Gate

Test from a clean target or isolated restore root with empty application,
model, package-manager, and runtime caches. Remove the WAN path or enforce an
egress-deny boundary outside the process under test; an application's
"offline" setting alone is insufficient. Observe attempted connections as well
as successful ones.

For each claimed tuple:

1. Restore the model, runtime, packages, configuration, and fixtures only from
   the preserved generation or its independent backup.
2. Reverify every consumed artifact against its manifest identity.
3. Install or assemble the runtime with no package index, model registry,
   container registry, DNS, or provider access.
4. Exercise a small deterministic or bounded semantic fixture for the claimed
   modality. Validate the real output: structured text, image dimensions and
   decode, transcript and timestamps, intelligible/decodable audio, decodable
   video, or expected embedding retrieval.
5. Fail if the process requests or requires an unarchived model shard, runtime,
   package, tokenizer, encoder, VAE, voice, font, custom node, or codec. Record
   every attempted external destination in bounded, non-sensitive evidence.
6. Prove the inference identity can read the restored generation but cannot
   mutate canonical custody.

Record `OFFLINE-VERIFIED` only for the exact passing tuple. An online launch, a
homepage, a runtime version command, or a model appearing in a UI is not a
capability test. Re-run the gate after changing any tuple member, conversion,
package closure, driver family, target platform, storage adapter, or restore
process.

## Closed-Provider Continuity

For S0 services, create a continuity dossier containing only material the owner
may retain:

- versioned official documentation, changelogs, and open-source SDK releases;
- API schemas, response-shape fixtures, tool definitions, and owned prompt or
  workflow templates;
- encrypted user exports and separately protected sensitive attachments;
- small rights-cleared evaluation fixtures and expected interface semantics;
- a compatibility adapter and explicit mappings to local substitutes;
- a capability-loss statement and last migration-test result.

The dossier preserves interface and work continuity, not inaccessible model
weights. Never label an SDK, API-compatible server, scraped output, or local
substitute as a backup of the closed provider model.

## Scenario Review

Require these outcomes before approving the runbook's use for a collection:

| Scenario | Required outcome |
| --- | --- |
| Mutable upstream revision | Resolve the revision to an immutable commit and per-file identities before acquisition; a later branch change produces a new proposed generation, not silent mutation. |
| Interrupted multi-file model download | Retain only partials bound to the exact manifest/content identities, resume under the immutable-acquisition rules, and promote nothing until every file passes full length and digest verification. |
| Git LFS omission | Detect pointer files or missing LFS objects during repository-completeness verification and reject the generation before testing or promotion. |
| Licence-changing variant | Capture and review the variant's own terms; preserve prior evidence unchanged and restrict or reject the new variant without inheriting the family name's licence claim. |
| Third-party GGUF | Catalog it as a derivative with upstream source digest, publisher, conversion tool/commit, command, quantization, output identity, and independent semantic test; retain the original upstream representation. |
| LM Studio runtime missing offline | Begin with empty runtime caches and denied egress; fail the tuple when the required runtime pack is requested, then archive it lawfully and repeat the restore test. |
| ComfyUI workflow with an unarchived custom node | Dependency-graph verification detects the missing pinned node or its package/model closure and blocks `OFFLINE-VERIFIED`. |
| Corrupt weight shard | Whole-file verification rejects and quarantines the shard; the model is not launched and a different good shard cannot mask the failure. |
| Unavailable closed API | Use the continuity dossier and exercise the same interface fixture against an explicit local substitute, while reporting capability loss and never claiming the provider weights were preserved. |
| Loss of the primary NAS | Restore manifests, canonical originals, selected derivatives, runtimes, packages, and fixtures from the independent failure-domain copy; pass the no-network tuple test before declaring recovery. |

Also reject any preservation claim based only on RAID, a same-system snapshot,
a local cache, a source URL, a container tag, or a successful online launch.

## Related Issues

- [RYA-236 - Research: Preserve AI model sovereignty on Olympus](https://linear.app/ryan-hayward/issue/RYA-236/research-preserve-ai-model-sovereignty-on-olympus)
- [RYA-237 - Add AI model and runtime preservation guidance](https://linear.app/ryan-hayward/issue/RYA-237/hive-mind-add-ai-model-and-runtime-preservation-guidance)
