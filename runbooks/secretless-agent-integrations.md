# Secretless Agent Integrations

Treat an LLM-controlled model and tool runtime as compromised. It may follow
direct or indirect prompt injection, call every visible tool, choose hostile
arguments, replay old messages, inspect its filesystem and process environment,
and run arbitrary code with its own authority.

The reusable boundary is a deterministic action broker that keeps upstream
credentials outside that runtime and authorizes each concrete effect before a
narrow connector executes it.

## Security Invariants

1. **Secret non-disclosure and effect authorization are different controls.**
   Hiding a credential prevents extraction; it does not make every authenticated
   use of that credential legitimate.
2. **Tool availability is not authorization.** A grant permits a particular
   caller to request bounded operations. The broker still authorizes every
   invocation and its concrete arguments.
3. **The agent receives effects, not upstream credentials.** The broker or
   connector never returns private keys, refresh tokens, session cookies,
   access tokens, signed reusable requests, or credential-helper output.
4. **Free-form HTTP is not a broker operation.** Expose typed, versioned
   operations with closed schemas and deterministic destination templates.
5. **Approval is exact, immutable, expiring, and single-use.** Missing,
   ambiguous, stale, mutated, replayed, or unverifiable approvals fail closed.
6. **Assume every boundary can fail.** Provider-side limits, revocation, and
   independently retained audit evidence contain broker or connector
   compromise.

## Architecture

```text
              untrusted security domain
       +----------------------------------+
       | model + tool runtime             |
       | short-lived broker workload ID   |
       +----------------+-----------------+
                        | typed operation + task/session grant
                        v
       +--------------------------------------------+
       | ACTION BROKER                              |
       |                                            |
       | PEP: authenticate, canonicalize, enforce   |
       | PDP: policy, grant, quota, approval rules  |
       | state: nonce, idempotency, revocation      |
       +------+------------------+------------------+
              ^                  | authorized operation
              | exact digest     v
       +------+--------+  +------+--------+     +-------------+
       | approval      |  | connector     |---->| upstream API|
       | service       |  | + secret use  |     +-------------+
       +---------------+  +------+--------+
                                  ^
                           +------+--------+
                           | secret store  |
                           +---------------+

       broker + connector ---- redacted events ----> append-only audit
       connector ------------ filtered result -----> model/tool runtime
```

`PEP` is the policy enforcement point; `PDP` is the policy decision point.
They may be separate services, but the connector must have no path that bypasses
the PEP decision. Network location alone grants no trust.

## Threat Model And Trust Boundaries

Protected assets are upstream credentials, user data, authorized actions,
approval integrity, policy and quota state, and audit evidence.

| Component | May hold or control | Must not trust | Compromise consequence |
| --- | --- | --- | --- |
| Model/tool runtime | Broker workload identity and bounded request grant | Prompts, retrieved content, tool arguments, local code, or prior results as authority | Attacker may submit any request the broker endpoint accepts, but should not obtain an upstream credential or exceed enforced grants |
| Action broker PEP/PDP | Policy, grants, quotas, canonical requests, replay and revocation state | Tool presence, caller-supplied identity, free-form intent, client-side validation | Attacker may authorize effects, so apply independent upstream limits and external audit |
| Secret store | Encrypted credential material and release policy | Agent or arbitrary broker-supplied secret names | Theft may expose every stored credential in scope |
| Connector | One provider's protocol, minimum credential use, fixed destination templates | Arbitrary URL, method, headers, redirect, resource, or raw response requested by the agent | Abuse is bounded to its provider account, operations, and upstream limits |
| Approval service | Approver identity, canonical display, step-up authentication, signed decision | Agent-rendered previews or mutable requests | A compromised approval path can authorize the displayed action class |
| Upstream API | Authoritative resource state and provider-side controls | Broker labels alone as proof of user intent | Upstream compromise or ambiguity can produce unintended or misreported effects |
| Audit sink | Redacted decisions, attempts, outcomes, reconciliation, and alerts | Broker authority to edit or delete history | Evidence may be lost or falsified if the broker can rewrite it |

This architecture does not make model output trustworthy or prove the upstream
performed the intended real-world result. It narrows authority and creates
evidence.

## Why Vaults And Generic Proxies Are Insufficient

A vault that returns a token to the agent changes where the credential rested,
not who can steal or misuse it. File permissions and short lifetimes also fail
when arbitrary agent-controlled code can invoke the token helper, read the
result, or make requests during the credential's valid window.

A generic HTTP proxy that injects credentials is a confused deputy when the
agent controls destinations, methods, paths, headers, bodies, redirects, or
response forwarding. It can turn a hidden credential into arbitrary
authenticated effects, SSRF, or a token-exfiltration path.

An action broker instead owns the upstream request construction. The agent can
ask for `message.send` or `repository.pull_request.create`; it cannot ask for
`http.request`. The broker validates the operation arguments against policy,
constructs one permitted upstream request, and returns a filtered domain result.

## Typed Operation And Grant Contract

Define each operation as a versioned schema with rejected unknown fields.
Canonicalize before policy or approval. Bind at least:

- protocol and operation-schema version;
- broker audience and policy version;
- request ID, idempotency key, server nonce, issue time, and expiry;
- authenticated workload, caller, user or principal, tenant, task, and session;
- operation name and concrete resource;
- normalized arguments and their canonical digest;
- recipient or destination identity, not merely a display name;
- purpose and data classification where policy depends on them;
- task/session grant ID, allowed action and resource patterns, and revocation
  handle;
- per-invocation, rolling, and concurrent quotas;
- required approval class and exact approval reference.

Keep argument semantics closed. Normalize Unicode, identifiers, paths, amounts,
hostnames, case rules, and ordered collections once. Reject duplicate or
ambiguous encodings. Hash binary or large content after constraining type and
size; the approval view must identify what that digest represents.

A task or session grant is authority to ask the broker, not authority to bypass
policy. Bind it to the authenticated workload and principal, permitted
operations, resources, recipients, parameter ceilings, expiry, quotas, and
approval requirements. Do not accept a grant copied to a different caller or
audience.

For every invocation, the broker must:

1. authenticate the workload independently of caller-supplied fields;
2. parse and canonicalize the typed request;
3. validate the grant, policy version, arguments, recipient, expiry, and quota;
4. require and verify exact-action approval when policy says so;
5. atomically reserve quota and consume the nonce or one-use approval;
6. call only the connector and destination fixed for that operation;
7. reconcile the authoritative outcome without blind retries;
8. redact the result and write append-only decision and outcome events.

An authorization or dependency timeout is a denial. An upstream timeout is an
unknown outcome to reconcile under the same idempotency key, not permission to
submit a second effect.

## Human Approval And Hardware Signers

The approval service should be outside the model-rendered interface. It must
show a trusted, fully parsed view of the canonical request: principal, caller,
operation, resource, recipient, material parameters, content digest or safe
preview, quota impact, expiry, and that approval is one-time. High-impact
actions should require fresh step-up authentication.

Bind the approval artifact to:

- protocol version and broker audience;
- approver, principal, workload, task, and session as applicable;
- canonical request digest and policy version;
- exact operation, resource, recipient, and material parameters;
- broker-issued nonce or operation ID;
- issue and expiry times;
- one-use semantics.

The broker must compare the artifact with the immutable request and atomically
mark the nonce or approval consumed as it reserves execution. Any mismatch,
mutation, cancellation, stale policy, expired challenge, failed step-up, or
uncertain state fails closed. Approval means permission to attempt that exact
operation; it is not proof of successful execution.

If policy needs a reusable mandate, provision it separately as a scoped grant
with explicit resource, parameter, expiry, and quota bounds. Do not turn an
exact-action human approval into a reusable mandate.

Hardware can make a signing key non-exportable, but only the verifier's durable
state can make a signed artifact single-use. An unattended signer on a
compromised host becomes a signing oracle. User presence is also insufficient
for high-impact effects unless a trusted display presents the canonical parsed
action before signing.

WebAuthn challenge, backup, and signature-counter signals can strengthen
authentication and clone-risk decisions, but they do not by themselves encode
an arbitrary broker operation or prove unique physical custody. Prefer a
non-backup-eligible device credential plus separately registered recovery
credentials when device binding is required. Treat counters as risk signals,
not absolute clone proof.

Bitcoin illustrates the distinction: a signature covers transaction data, while
network UTXO state prevents the same output from being spent twice. A general
action protocol needs its own server-issued challenge and atomic consumed state.
For the same reason, hardware-backed SSH authentication is not a substitute for
approval of the broker's exact operation digest.

## Credentials And Workload Identity

Use workload identity to authenticate the runtime to the broker. Keep that
identity short-lived, audience-bound, sender-constrained where supported,
scoped to one tenant and broker, and independently revocable. It should not
authenticate directly to the upstream provider.

Inside the trusted boundary, prefer upstream credentials that are:

- short-lived and minted only when required;
- audience- or resource-bound;
- restricted to minimum actions and resources;
- sender-constrained where the upstream supports proof of possession;
- isolated per tenant, connector, provider account, and environment;
- capped by provider-side quotas, roles, or delegated mandates;
- rotated and revocable without the model runtime.

These controls reduce theft and replay. They do not replace the broker's
per-invocation decision. A one-hour, repository-scoped installation token is
still a reusable bearer credential if returned to the agent; keep it inside the
connector.

## Egress, Request Construction, And Responses

Default-deny network egress from the model/tool runtime. Permit only the broker
and separately justified content services; block direct access to upstream API,
token, metadata, secret-store, and approval backends.

For each connector:

- allowlist scheme, host, port, method, path template, content type, request
  fields, and response size;
- derive destinations from configuration and validated identifiers, never a
  caller-supplied URL;
- require TLS and validate the intended service identity;
- reject embedded credentials, fragments, alternate IP encodings, and
  unexpected ports;
- resolve and validate destinations at connection time; block loopback,
  link-local, private, reserved, and metadata destinations unless an exact
  internal target is intentionally configured;
- disable redirects or revalidate every hop under the same rules;
- pin the validated resolution through connection where practical to resist
  DNS rebinding and validation/use races;
- strip caller-supplied authorization, forwarding, host, and hop-by-hop headers;
- enforce request size, rate, concurrency, and response limits.

Return typed results, not raw provider responses. Remove credentials, signed
URLs, authorization headers, cookies, internal identifiers, excessive error
detail, hidden instructions, and fields the operation does not need. Treat
upstream text as untrusted data when it re-enters model context.

MCP URL elicitation can collect a user's sensitive input out of band without
passing it through the client. It solves a disclosure path, not effect
authorization: subsequent tool calls still need the operation contract and
broker policy above.

## Audit, Revocation, And Recovery

Write decision, denial, approval, reservation, connector attempt, upstream
outcome, redaction, reconciliation, and revocation events to an append-only
sink. The broker may append but should not edit or delete prior events. Export
or replicate evidence into a separately administered boundary.

Record request and policy digests, identities, operation, resource, recipient,
quota effects, approval reference, connector and upstream request IDs,
timestamps, result class, and redaction metadata. Do not record secret values,
authorization headers, private keys, full sensitive payloads, or unrestricted
provider responses.

Provide an operator path independent of the model runtime to:

- deny new grants and invocations;
- revoke workload identities, task/session grants, and pending approvals;
- stop connectors and disable upstream credentials or delegated mandates;
- freeze or cancel pending effects where supported;
- preserve and reconcile submitted or unknown outcomes;
- rotate credentials, review policy, and explicitly re-enable service.

Test the kill switch and recovery process. Revocation propagation time is part
of the risk budget.

## Deployment Patterns

### Local agent

The strongest pattern places broker, secrets, connectors, approval, and audit on
a separate host or security domain. The agent host receives only a workload
identity accepted by the broker and has default-deny egress to upstreams.

Same-host separation can reduce accidental leakage when the agent runs as an
unprivileged account and cannot inspect broker processes, sockets, files,
service configuration, kernel state, or privileged network paths. It is not a
strong secret boundary against an agent with root-equivalent authority on that
host. Root can normally inspect or alter the broker, steal credentials in use,
change egress controls, or impersonate callers. Move the trusted boundary off
host or remove that authority; do not claim both same-host root control and
strong isolation.

### Hosted agent

Use a customer-controlled remote broker. The hosted runtime authenticates with
a narrow workload identity and can reach only the customer's typed broker
endpoint. The customer boundary owns provider authorization, stored
credentials, policy, approval UI, connectors, revocation, and audit export.
Provider tokens never transit the hosted runtime.

Bind every request to customer, user, workload, task/session grant, and broker
audience. Prefer outbound customer-side connector traffic so the broker does
not expose a generic inbound proxy. A hosted platform's tool catalog remains
discovery metadata, not authorization.

## Migration Examples

| Existing integration | Secretless migration | Required authorization |
| --- | --- | --- |
| App private key or refresh credential in the agent runtime | Move credential and token exchange into a provider connector; expose typed repository or application operations; keep minted access tokens internal | Bind repository/app resource, operation, ref or object, content digest, permissions, expiry, quota, and approval |
| Static API key used by generated HTTP | Store the key in one connector; replace arbitrary URL/method/body with a fixed operation and request template | Bind tenant, resource, permitted query or mutation fields, recipient, rate, result fields, and expiry |
| Messaging bot token | Expose `message.send`, `draft.create`, or bounded read operations; keep token, workspace, and API origin in the connector | Bind workspace, canonical channel or recipient, message/attachment digest, rate, external-recipient policy, and approval |
| Model-provider API key | Put inference behind a customer gateway or connector, or use provider-supported workload identity without returning it to tools | Bind provider/model allowlist, tenant, data class, maximum input/output, rate and spend quotas, retention policy, and result filtering |

Do not migrate by replacing a static secret with a command that prints a
short-lived token. Replace credential access with effect-only operations.

## Residual Risks

- A compromised broker can authorize effects within upstream account limits.
- A compromised connector or secret store can misuse its provider credential.
- A deceptive request or compromised approval display can induce valid
  approval of an unwanted action.
- Coarse upstream APIs may prevent exact least privilege or authoritative
  reconciliation.
- Provider compromise, ambiguous resource identity, redirects, or mutable
  external state can change the real effect after local validation.
- Filtered upstream content can still contain prompt injection or sensitive
  data the schema intentionally returns.
- Identity issuers, policy administrators, recovery credentials, audit
  administrators, and build/deployment pipelines remain privileged.
- Denial of service, quota exhaustion, privacy leakage through metadata, and
  traffic analysis remain possible.
- Non-exportable keys reduce key theft but do not constrain a signing oracle.

Document the maximum credible loss for each boundary and add independent
upstream limits where the broker alone cannot contain it.

## Adversarial Validation Matrix

| Scenario | Expected result |
| --- | --- |
| Direct prompt injection requests a disallowed action | Broker denies the operation or arguments; no connector call or quota consumption beyond denial accounting |
| Indirect injection in a page, email, document, or API response changes arguments | External content remains data; canonical operation is re-authorized and any material change invalidates prior approval |
| Arbitrary shell runs in the agent environment | No upstream credential or token helper output is available; default-deny egress prevents direct provider access |
| Agent invokes a credential or signing helper | No token-returning helper exists in the agent boundary; signer requires an exact broker challenge and returns no reusable upstream credential |
| Agent abuses a generic proxy | No raw HTTP operation exists; unknown operation, destination, method, header, body, and redirect fields are rejected |
| SSRF, redirect, alternate IP, or DNS rebinding targets an internal service | Connector derives an allowed destination, validates every connection/hop, and blocks non-approved address classes |
| Approval is replayed, races, or request data changes after preview | Digest, nonce, expiry, policy version, and atomic consumed state reject replay or mutation before a second connector call |
| Caller reuses another task, session, user, or tenant handle | Broker derives caller identity from authentication and rejects the mismatched grant or state handle |
| Concurrent calls try to exceed quota | Atomic reservation admits only operations within per-call, rolling, and concurrent limits |
| Broker fails before connector submission | Operation fails closed; reservation and audit state permit safe recovery |
| Connector times out after submission | Outcome remains `unknown`; reconciliation uses the same idempotency key and never blindly repeats the effect |
| Broker or connector is compromised | Provider-side scope and quotas bound effects; independent audit remains available; kill switch revokes credentials and grants |
| Upstream response contains a credential or prompt injection | Response schema and redaction remove disallowed fields; returned text remains labeled untrusted |
| Operator revokes access | New invocations fail, pending approvals cannot execute, credentials are disabled, and submitted/unknown outcomes remain reconcilable |

Record the policy version, fixture, expected and actual decision, connector-call
count, upstream evidence, audit event IDs, and redaction result. Run the matrix
before production, after boundary changes, and after credential or policy model
changes.

## Relationship To Existing Guidance

- `credentials/NOTES.md` remains the metadata and no-secret recording rule.
  This runbook supersedes any interpretation that protected storage, file
  permissions, or short-lived credentials alone secure a compromised agent.
- `runbooks/agent-email-identity.md` describes a mailbox bridge that can serve
  as a connector, but model-requested sends still need per-invocation
  authorization.
- `runbooks/github-app-pr-workflow.md` describes scoped operator automation. An
  untrusted model runtime should receive typed repository effects, not its token
  helper output.
- `runbooks/agent-payment-authority.md` is the specialized extension for moving
  value, with aggregate budgets, custody, rail adapters, and reconciliation.
  It is not replaced by this general integration boundary.

## References

- [RYA-119 - Document secretless credential-broker architecture for LLM agents](https://linear.app/ryan-hayward/issue/RYA-119/hive-mind-document-secretless-credential-broker-architecture-for-llm)
- [NIST SP 800-207: Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final)
- [RFC 9700: Best Current Practice for OAuth 2.0 Security](https://www.rfc-editor.org/rfc/rfc9700.html)
- [RFC 9396: OAuth 2.0 Rich Authorization Requests](https://www.rfc-editor.org/rfc/rfc9396.html)
- [RFC 9449: OAuth 2.0 Demonstrating Proof of Possession](https://www.rfc-editor.org/rfc/rfc9449.html)
- [RFC 9421: HTTP Message Signatures](https://www.rfc-editor.org/rfc/rfc9421.html)
- [OWASP AI Agent Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/AI_Agent_Security_Cheat_Sheet.html)
- [MCP Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices)
- [MCP URL Elicitation](https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation)
- [Ledger device-app cryptography threat model](https://developers.ledger.com/docs/device-app/explanation/cryptography)
- [Bitcoin transaction and UTXO model](https://developer.bitcoin.org/devguide/transactions.html)
- [Web Authentication Level 3](https://www.w3.org/TR/webauthn-3/)
- [GitHub hardware-backed SSH key guidance](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [GitHub App installation access tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
