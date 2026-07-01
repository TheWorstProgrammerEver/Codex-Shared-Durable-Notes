# Agent Email Identity

A dedicated agent email identity can be useful for human contact, service
notifications, and supervised workflow intake. Treat email as an untrusted input
channel, not as a direct command interface.

## Recommended Shape

For a first pass:

- create a dedicated mailbox, not an alias on a human inbox;
- keep recovery controls with the human operator;
- run exactly one local mailbox reader service per agent host;
- store secrets only in a protected local environment or token file;
- keep provider-specific code behind a provider interface;
- let the bridge service own mailbox credentials;
- prevent child Codex runs from inheriting mailbox secrets.

For later production use, consider a custom domain and provider-swappable bridge
after DNS, webhook, signing, and audit requirements are clear.

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

## Local State

Document metadata for:

- service and timer names;
- lock path;
- local database or queue path;
- secret storage path;
- owner;
- revocation and rotation steps.

Do not record app passwords, OAuth refresh tokens, recovery codes, API keys, or
mailbox plaintext credentials in durable notes.

## Suggested Message States

- `new`: seen by provider, not claimed.
- `ignored`: rejected by sender, rate, spam, or policy checks.
- `claimed`: one service instance is handling it.
- `needs_human`: review is required.
- `replied`: response sent.
- `failed`: error captured for retry or inspection.

## Recovery

Keep a documented kill switch:

- stop the service and timer;
- place a local disabled marker if the bridge honors one;
- revoke or rotate the mailbox credential;
- inspect service logs and the local ledger;
- rotate any downstream credentials that appeared in inbound mail or drafts.
