# Agent Payment Authority

Agents should exercise delegated payment capabilities, not own funds or receive
general-purpose wallet access. The human or business remains the legal and
economic principal. A separately enforced broker decides whether each payment
intent is authorized before a rail adapter can move value.

This is an architecture and operating runbook, not legal, tax, accounting, or
regulatory advice.

Use `runbooks/secretless-agent-integrations.md` for the general credential and
effect-authorization boundary. This runbook adds payment-specific custody,
aggregate budget, settlement, and reconciliation controls.

## Core Invariant

Keep payment authorization outside the model runtime:

```text
PaymentIntent -> policy broker -> rail adapter -> receipt
```

The agent may propose a typed `PaymentIntent`. It must not be able to invoke the
rail adapter, signer, wallet, bank, exchange, or payment-service administrator
interface directly. Model sandbox and approval settings are useful defense
layers around the agent runtime, but they are not the payment authority
boundary.

**Layering warning:** model sandbox or approval settings, per-request payment
ceilings, pay-only RPC scopes, and remote signers each reduce a different risk.
None substitutes for aggregate, broker-enforced budgets.

The broker should:

1. authenticate the agent's narrow, revocable capability;
2. canonicalize and validate the merchant, purpose, amount, and expiry;
3. reserve both per-transaction and aggregate budget atomically;
4. obtain any approval bound to the exact intent;
5. invoke one rail adapter with an idempotency key;
6. reconcile an authoritative outcome before releasing or finalizing the
   reservation;
7. emit an append-only policy decision and payment receipt.

If required policy state, exchange-rate data, approval state, or adapter
reconciliation is unavailable, fail closed. A timeout is an unknown outcome,
not evidence that no payment occurred.

## Trust Boundaries

| Boundary | Holds or controls | Must not receive | Compromise boundary |
| --- | --- | --- | --- |
| Principal | Funds, policy ownership, approvals, treasury, recovery | Agent-generated instructions treated as authority | Principal compromise can change policy and recover or move all funds |
| Agent runtime | A short-lived capability to submit bounded intents | Wallet seed, private key, bank or exchange login, rail admin credential, unrestricted payment token | Compromise can submit malicious intents only within broker policy and capability limits |
| Policy broker | Authoritative policy, budget ledger, intent state, adapter invocation | Treasury credentials or an automatic path to replenish operating funds | Compromise may exhaust the bounded operating float or downstream rail limit, so independent rail-side caps and audit are still required |
| Rail adapter | Minimum credential and protocol logic for one rail | Model prompts, broad fleet policy changes, unrelated rail credentials | Compromise is limited to one rail, account, asset, network, and configured float or mandate |
| Signer or wallet | Rail keys or delegated payment instrument, preferably isolated from agent hosts | Model context, treasury access, exchange credentials, general admin access | Compromise can move the funds or use the mandate it controls; cap that value independently |
| Merchant or origin | Quote, invoice, cart, fulfillment, refund response | Principal credentials or authority to redefine an intent | Merchant input is untrusted until identity, origin, amount, and order binding are verified |
| Audit and accounting sink | Decisions, receipts, reconciliation, alerts | Signing or payment authority | Keep write access narrow so a payment-side compromise cannot erase evidence |

The capability identifies the principal, fleet or agent, permitted operation,
policy version, audience, expiry, and revocation handle. It is authority to ask
the broker, not ownership of funds and not authority to bypass policy.

## Payment Intent Contract

Use a typed, canonical representation. At minimum, bind:

- intent ID, idempotency key, nonce, creation time, and expiry;
- principal, agent identity, capability ID, and policy version;
- canonical merchant ID and authenticated origin;
- purpose, order or cart digest, item/category summary, and fulfillment target;
- requested rail constraints, asset, network, and maximum rail-native amount;
- maximum accounting-currency value and currency;
- maximum fee, refundability requirement, and subscription or recurrence terms;
- quote, invoice, or payment-request digest where one exists;
- requested approval class and references to any prior approved mandate.

Sign or message-authenticate the canonical intent at the capability boundary.
Reject unknown fields, ambiguous amounts, negative values, unsupported
precision, expired intents, and changes after approval. Never derive payment
authority from free-form prompt text alone.

## Broker Policy

### Merchant and purpose

- Deny by default. Match a stable merchant identity and authenticated origin,
  not a display name supplied by content.
- Require out-of-band approval the first time a merchant is encountered.
- Pin or verify rail-specific identity where practical: payment-provider
  account, invoice issuer, destination address, chain and contract, or other
  authenticated merchant metadata.
- Re-evaluate redirects, marketplace sub-merchants, changed settlement
  destinations, and material cart changes as new trust decisions.
- Restrict categories, purposes, fulfillment destinations, subscriptions, and
  refundability according to the principal's policy.

### Amount, aggregate budget, and rate

Enforce all applicable limits, not whichever one is easiest for the rail:

- per-transaction principal, fleet, agent, capability, and merchant limits;
- rolling aggregate limits across short and long windows;
- transaction-count and velocity limits;
- merchant, category, asset, network, and fee limits;
- concurrent pending-payment limits;
- a hard operating-float or downstream mandate limit.

Reserve budget atomically before adapter invocation. Pending and
unknown-outcome attempts remain reserved. Successful payments consume the
reservation, including fees according to policy. A rejection known not to have
moved value may release it. Refunds should be separate ledger events and should
not automatically restore spend authority unless policy explicitly permits it.

This prevents a fleet from defeating controls through concurrency or many
individually valid, sub-threshold payments.

### Dual denomination

Keep the accounting unit separate from the settlement rail. Every decision
should enforce:

1. a limit in the principal's accounting currency; and
2. a limit in the rail-native denomination.

Record the rate source, quote ID where available, observation time, maximum
age, conversion direction, spread or slippage rule, and rounding method.
Reject stale or unavailable quotes. Do not let the agent or merchant choose the
authoritative rate source. Re-evaluate when the adapter's final amount exceeds
the approved tolerance; do not silently substitute a newer, more expensive
quote.

### Idempotency and replay protection

- Scope every idempotency key to one principal and canonical intent digest.
- The same key and same digest returns the existing decision or outcome.
- The same key with different content is rejected.
- Consume nonces once, enforce intent and approval expiry, and reject old policy
  versions after revocation.
- Carry the idempotency key into the adapter when the rail supports it.
- After a timeout, query by the same key or payment reference. Do not create a
  new payment merely to retry transport.
- Where a rail lacks native idempotency, keep an adapter-side state machine and
  reconcile the destination proof before another attempt.

Useful states are `received`, `denied`, `approval_required`, `reserved`,
`submitted`, `unknown`, `succeeded`, `failed`, `refunded`, and `revoked`.
Transitions must be durable and monotonic except for explicit reconciliation
events.

### Approvals

Approval should be out of band from untrusted merchant content and bound to:

- principal and approver identity;
- canonical intent digest;
- merchant and origin;
- maximum amount in both denominations;
- purpose or order digest;
- allowed rail and recurrence;
- issue time, expiry, and one-time or bounded-use counter.

Use thresholds such as human approval for a first merchant, amount above the
automatic ceiling, a subscription, a non-refundable purchase, a high-risk
category, or a changed destination. Multi-party approval can be required by
principal policy. An approval is not a reusable natural-language instruction.

### Revocation and emergency shutdown

Provide one operator action that immediately:

- denies new intents at the broker;
- revokes agent capabilities and pending approvals;
- cancels or freezes pending adapter operations where the rail permits;
- revokes or rotates rail credentials and delegated mandates;
- disables automatic replenishment, if any exists;
- alerts operators and preserves the audit trail for reconciliation.

The kill switch must work without the model runtime and should be tested
regularly. Recovery requires explicit re-enable, fresh capabilities, policy
review, credential rotation where indicated, and reconciliation of all
`submitted` or `unknown` payments.

## Funds and Credential Custody

Keep a capped operating float separate from treasury. Replenish it manually
after reviewing receipts and remaining budget. Do not expose an automatic
treasury sweep to the broker.

The agent and its child processes must never receive:

- bank or exchange credentials;
- wallet seeds or private keys;
- unrestricted card details or payment-service admin credentials;
- signer administrator credentials;
- a path to raise limits or replenish the operating float.

For rails that are not literally prefunded, approximate the same blast-radius
boundary with enforceable provider-side limits: a merchant-locked or
single-purpose virtual card, a capped delegated mandate, account-level velocity
controls, or another independently administered ceiling. The broker's own
database limit is not enough to contain a compromised broker.

## Rail Adapters

The broker contract stays stable while adapter behavior varies.

### Bitcoin Lightning and L402

L402 makes a paid HTTP challenge machine-readable: the client receives a
Lightning invoice, pays it, combines the proof with the access token, and
retries the request. This is useful for paid APIs and small machine-native
transactions, but settled payments are generally not reversible.

Use the layers accurately:

- `lnget --max-cost` limits one auto-paid request. It is not a rolling or
  fleet-wide budget.
- A pay-only macaroon limits the Lightning RPC methods available to its bearer.
  It does not enforce an aggregate spend limit.
- A remote signer keeps private keys off the agent host. It does not decide
  whether repeated otherwise-valid payments fit business policy.
- L402 token caching may prevent a second payment for the same access grant,
  but it is not general payment idempotency or budget accounting.

Keep the pay-only credential inside the adapter boundary, not in the model
runtime. Enforce aggregate budgets in the broker, cap the Lightning operating
wallet, set routing-fee limits, validate the invoice amount and destination,
and store the payment hash/preimage or equivalent proof in the receipt.
Regtest, `lnget --no-pay`, and disposable-value mainnet trials are distinct
rollout stages.

### Delegated card or fiat mandates

Cards and fiat providers offer broad merchant acceptance and may support
authorization, capture, refund, dispute, virtual-card, and merchant-locking
controls. They also introduce asynchronous settlement, provider risk checks,
incremental authorization, chargebacks, and recurring-payment semantics.

Keep card data and provider API credentials in the adapter. Prefer a
single-purpose virtual instrument or typed delegated mandate with provider-side
amount, merchant, time, and recurrence limits. Bind authorization and capture
to the same intent. Treat tips, partial captures, currency conversion,
subscriptions, and merchant-initiated transactions as explicit policy cases,
not harmless variations.

### Stablecoin and machine-payment protocols

Machine-payment protocols can coordinate HTTP-native fiat or stablecoin
payments, including small or recurring charges. The adapter must still pin the
network, asset issuer, token contract, decimal precision, recipient, and
payment method.

Stable denomination does not remove issuer, depeg, chain, smart-contract,
bridge, fee, finality, sanctions-screening, or custody risk. Restrict token
allowances, avoid arbitrary contract calls, define confirmation/finality
requirements, protect nonces from replay, and count network fees in policy.
Keys remain in an isolated wallet or signer behind the adapter, with only a
bounded operating balance.

## Receipt and Accounting Record

Emit a receipt for approval, denial, submission, success, failure, refund, and
reconciliation events. Include:

- intent ID, idempotency key, canonical intent digest, and timestamps;
- principal, agent, capability, policy version, decision ID, and approval
  references;
- canonical merchant, authenticated origin, purpose, order/cart digest, and
  fulfillment reference;
- rail, provider, asset, network, rail-native amount, and fee;
- accounting currency and value;
- exchange-rate source, quote ID, observation time, age, conversion direction,
  spread/slippage, and rounding;
- adapter and external payment IDs;
- payment proof appropriate to the rail;
- outcome, reason code, reversibility/finality state, and failure detail;
- refund, rejection, dispute, or reconciliation references.

Write records to an append-only, access-controlled audit sink separate from the
agent host. Reconcile adapter/provider statements and balances to broker
reservations and receipts. Alert on missing receipts, long-lived unknown states,
budget drift, repeated denials, merchant changes, and unexpected replenishment.

## Threat Review

| Threat | Required response |
| --- | --- |
| Prompt injection or compromised agent | Treat content as data; broker accepts only typed intents under a narrow capability |
| Merchant spoofing or redirect | Verify canonical identity, origin, quote/invoice binding, and destination; require first-merchant approval |
| Duplicate request or transport retry | Reuse the same idempotency key and reconcile the existing payment |
| Replayed intent or approval | One-time nonce, digest binding, expiry, durable consumed state |
| Many small payments | Atomic rolling aggregate and velocity limits across the fleet |
| Irreversible settlement | Strong pre-payment checks, small float, finality-aware receipts, no blind retry |
| Compromised agent host | No rail credentials or keys; revoke its capability; inspect submitted intents |
| Compromised broker or credential theft | Independent float/mandate ceiling, scoped adapter credentials, separate audit, immediate rail-side revocation |
| Stale or manipulated FX quote | Approved rate sources, maximum quote age, dual limits, fail closed |
| Unavailable signer or provider | Preserve reservation as pending/unknown; retry transport only with the same payment identity |

## Staged Rollout

1. **No-pay simulation:** use mock adapters and policy fixtures; generate
   decisions and receipts without any rail credential or value.
2. **Rail test environment:** use Lightning regtest/testnet or provider
   sandboxes; inject timeouts, duplicates, stale quotes, and unavailable
   signers.
3. **Disposable-value pilot:** use one agent, one approved merchant, manual
   approval for every payment, a tiny manually replenished float, and immediate
   receipt reconciliation.
4. **Bounded automation:** allow low-value payments only after first-merchant
   approval; enable rolling budgets, alerts, and tested emergency revocation.
5. **Hardened expansion:** add remote signing or provider-side delegated
   instruments where appropriate, expand merchants incrementally, and increase
   limits only from measured loss, reconciliation, and incident evidence.

Do not progress merely because individual payments succeeded. Test the policy
boundary and worst-case loss at every stage.

## Scenario Validation

| Scenario | Expected result |
| --- | --- |
| One approved payment | One atomic reservation, one adapter submission, one receipt, correct dual-denomination accounting |
| Retry after timeout | Same idempotency key returns or reconciles the original `submitted`/`unknown` payment; no second spend |
| Replayed intent | Consumed nonce or expired intent is rejected without adapter invocation |
| Many sub-threshold payments | Rolling amount, count, or velocity limit stops the sequence across concurrent agents |
| New merchant | Denied or held for first-merchant approval using canonical identity |
| Stale exchange-rate quote | Fails closed before reservation or adapter invocation |
| Compromised agent process | Malicious intents remain inside capability, merchant, amount, rate, and aggregate limits; revocation stops new submissions |
| Compromised broker | Independent operating-float or provider mandate bounds loss; external audit remains available |
| Unavailable signer | Reservation remains pending and is safely released only after authoritative failure; no new payment identity is created |
| Rejected or refunded purchase | Rejection releases only an unspent reservation; refund is a linked ledger event and does not silently restore authority |
| Emergency revocation | New intents fail, capabilities and approvals are revoked, rail credentials are disabled, and unknown payments remain queued for reconciliation |

Record the test fixture, policy version, expected result, actual result, and
evidence for each scenario before enabling or increasing real-value authority.

## Compliance Integration Points

Make jurisdiction and business rules configurable inputs owned by the
principal: tax treatment, invoice retention, merchant and sanctions screening,
consumer protection, refund and dispute rights, licensing, reporting,
accounting classification, data residency, and record-retention periods.

Do not encode one jurisdiction's assumptions as universal policy. Obtain
qualified legal, tax, compliance, and accounting advice for the principal and
rails in use.

## References

- [RYA-112 - Document rail-agnostic payment authority architecture for agent fleets](https://linear.app/ryan-hayward/issue/RYA-112/document-rail-agnostic-payment-authority-architecture-for-agent-fleets)
- [Lightning Agent Tools](https://github.com/lightninglabs/lightning-agent-tools)
- [Lightning Agent Tools: L402 and lnget](https://github.com/lightninglabs/lightning-agent-tools/blob/main/docs/l402-and-lnget.md)
- [Lightning Agent Tools: security model](https://github.com/lightninglabs/lightning-agent-tools/blob/main/docs/security.md)
- [Lightning Labs: L402](https://docs.lightning.engineering/the-lightning-network/l402)
- [Google: Developer's Guide to AI Agent Protocols](https://developers.googleblog.com/en/developers-guide-to-ai-agent-protocols/)
- [Google Agent Payments Protocol](https://github.com/google-agentic-commerce/AP2)
- [Machine Payments Protocol](https://mpp.dev/)
- [Stripe: Introducing the Machine Payments Protocol](https://stripe.com/blog/machine-payments-protocol)
- [OpenAI: Agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security)
