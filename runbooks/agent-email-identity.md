# Agent Email Identity

A dedicated agent email identity can be useful for human contact, service
notifications, and supervised workflow intake. Treat email as an untrusted input
channel, not as a direct command interface. For a first deployment, prefer a
managed custom-domain mailbox provider over self-hosted internet mail.

## Provider-First Recommendation

Use a managed mailbox provider that supports custom domains, IMAP, SMTP, and
mailbox-scoped credentials. Purelymail and Migadu are examples of providers that
fit this shape; choose based on operator needs, current pricing, APIs, quotas,
support model, and account controls.

Recommended v0 shape:

- create one mailbox per agent, not an alias on a human inbox;
- use an agent-mail subdomain such as `agents.example.com`, not the root domain;
- keep recovery controls with the human operator;
- give each agent only mailbox-scoped or app-specific IMAP/SMTP credentials;
- run one local mailbox reader/sender bridge per agent host;
- keep provider-specific behavior behind a small provider interface;
- prove inbound delivery, outbound sending, IMAP login, SMTP send, and
  credential revocation before building more automation.

This avoids per-agent consumer-account setup, keeps billing and recovery with
the operator, and gives the local bridge a provider-neutral interface.

## Decision Rubric

Choose a managed custom-domain mailbox provider when:

- the immediate goal is reliable mailbox delivery and low-volume sending;
- the agent only needs IMAP/SMTP access through a bridge;
- the operator wants simple recovery, billing, DNS verification, and revocation;
- mailbox creation and deletion are more important than owning mail
  infrastructure;
- a provider's quotas and acceptable-use rules fit the expected low-volume
  agent traffic.

Consider self-hosted mail only after the provider-first path is proven, and only
if the operator explicitly wants to own:

- MX ingress and public delivery paths;
- sender reputation, abuse handling, bounce handling, queues, and logs;
- TLS, DKIM, SPF, DMARC, spam filtering, backups, and upgrades;
- a smarthost or relay strategy when direct outbound delivery is unsuitable;
- provider migration and incident response for mail infrastructure itself.

Self-hosted mail servers such as Stalwart, or a larger Hermes-style local mail
platform, can be viable later, but they are not a good v0 just to give agents
email identities. They add DNS, ingress, relay, backup, reputation, and abuse
operations before the first agent mailbox is validated.

## DNS Shape

Use a subdomain for agent mail to isolate DNS and sender reputation from human
or business mail. Keep root-domain MX records unchanged unless the operator
intentionally wants to move root-domain mail.

Typical provider-generated records for the agent-mail subdomain include:

- MX records for inbound delivery;
- SPF TXT records for authorized outbound senders;
- DKIM TXT or CNAME records for message signing;
- DMARC TXT records for policy and reporting;
- provider ownership or verification records.

Treat provider portal or API output as the source of truth for exact record
names, values, priorities, and TTLs. Do not copy provider-generated secrets or
private account details into shared durable notes.

## Provisioning Checklist

Human/operator prerequisites:

- choose the provider and create the provider admin account;
- own billing, admin MFA, recovery email, recovery keys, and emergency
  revocation;
- add provider-required DNS records for the agent-mail subdomain;
- create one mailbox per agent with a clear display name and address.

Technical validation:

1. Provider verifies DNS records for the agent-mail subdomain.
2. Public DNS shows MX, SPF, DKIM, and DMARC records where applicable.
3. Inbound test mail reaches each agent mailbox.
4. Outbound test mail sends with the intended display name and address.
5. SPF, DKIM, and DMARC alignment pass where visible in received headers.
6. IMAP login works from the intended host using a scoped credential.
7. SMTP send works from the intended host using a scoped credential.
8. Credential revocation or rotation is tested before the bridge is trusted.

## Local Bridge Requirements

Run one mail bridge per agent host. The bridge should own mailbox credentials and
should expose only structured, policy-checked inputs and outputs to Codex.

Bridge responsibilities:

- poll only the agent mailbox Inbox or a dedicated processing folder;
- use a local lock so only one reader runs at a time;
- keep durable processing state in local agent state, commonly SQLite;
- deduplicate by provider, provider message ID, RFC 822 `Message-ID`, sender,
  recipient, and received timestamp;
- keep provider-specific IMAP/SMTP details behind an adapter;
- submit outbound mail through a bridge-mediated queue or draft workflow;
- prevent child Codex runs from inheriting mailbox secrets.

## Safety Rules

- Do not let inbound email directly execute shell commands.
- Treat subjects, bodies, display names, headers, and attachment names as
  untrusted data.
- Use sender allowlists before model invocation.
- Add per-sender and global rate limits.
- Poll only intended folders or labels, not spam or trash.
- Cap body size and prefer sanitized plain text.
- Ignore attachments by default until a human explicitly approves parsing.
- High-impact actions should become Linear issues, comments, or draft replies
  requiring review.
- Outbound mail should go through a bridge-mediated queue, not arbitrary SMTP or
  API access from generated code.

## Credential Metadata

Store mailbox secrets only in protected local configuration, a service
environment file, or the platform's secret store. Parent directories should be
private to the agent account, and secret files should be readable only by the
owning agent or service account.

Durable notes may record only metadata:

- purpose;
- owner;
- scope;
- storage location;
- expected permissions;
- owning service or workflow;
- revocation path;
- rotation steps;
- last validation date.

Never record app passwords, OAuth refresh tokens, provider API keys, provider
admin credentials, TOTP seeds, recovery codes, or mailbox plaintext credentials
in durable notes.

## Local State

Document local operational metadata for:

- service and timer names;
- lock path;
- local database or queue path;
- secret storage location;
- owner;
- revocation and rotation steps.

These values belong in local durable notes because they vary by host. Shared
durable notes should describe the shape only, not real local paths or hostnames.

## Suggested Message States

- `new`: seen by provider, not claimed.
- `ignored`: rejected by sender, rate, spam, or policy checks.
- `claimed`: one service instance is handling it.
- `needs_human`: review is required.
- `replied`: response sent.
- `failed`: error captured for retry or inspection.

## Self-Hosted Sequencing

Use self-hosted mail as a later infrastructure project, not as the default
mailbox-provisioning path.

Recommended sequence:

1. Prove managed-provider mailboxes for the initial agents.
2. Prove inbound delivery, outbound sending, IMAP login, SMTP send, and scoped
   credential revocation.
3. Build the local bridge against IMAP/SMTP with the safety rules above.
4. Revisit self-hosted mail only if managed providers become a bottleneck or the
   operator explicitly wants to own mail operations.

If self-hosting is chosen later, keep the bridge contract stable so provider
mailboxes, Stalwart/JMAP, SMTP relays, or other mail backends can be swapped
without changing the agent safety model.

## Recovery

Keep a documented kill switch:

- stop the service and timer;
- place a local disabled marker if the bridge honors one;
- revoke or rotate the mailbox credential;
- inspect service logs and the local ledger;
- rotate any downstream credentials that appeared in inbound mail or drafts.
