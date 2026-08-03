# Linear Agent Identity

Use a Linear app user when a durable agent or unattended service needs its own
visible actor, audit trail, team access, and revocation boundary. A different
credential alone does not create a different actor: personal API keys and
user-authorized OAuth or MCP sessions still attribute mutations to the human
user who authenticated them.

## Identity Model

Prefer one private OAuth application per durable agent identity. Set the
application name and icon to the identity users should see, keep its
distribution private to the intended workspace, and install or authorize it
with `actor=app`. Linear then performs mutations such as issue creation,
comments, and status changes as that app user.

Do not use one fleet-wide app when agents need separate attribution or
revocation. Separate app users provide separate visible identities, workspace
installation IDs, client secrets, tokens, team grants, and kill switches.

These mechanisms are not equivalent:

- A personal API key acts as its human owner. Use it only as a temporary
  operator fallback or when the workflow intentionally acts as that human.
- OAuth with the default `actor=user` acts as the authorizing human. Use it for
  interactive work intentionally performed as the signed-in user.
- OAuth authorized with `actor=app`, and tokens from the client-credentials
  grant, act as the installed app user. Use them for durable agents and service
  accounts that need distinct attribution.
- `createAsUser` and `displayIconUrl` only add an upstream name and avatar to a
  supported app mutation. They do not create a separate agent identity,
  credential, team grant, or revocation boundary.

An email-backed Linear member or guest remains a fallback when a workflow
actually requires an interactive Linear login or a member-only capability.
Do not provision one merely to make API comments look distinct. An app user is
installed and managed as an application rather than signed in as a human, and
does not consume a billable user seat.

## Provisioning

1. Create a private OAuth application for the durable agent. Give it a stable,
   recognizable name and icon. Keep recovery and application administration
   with workspace administrators.
2. Enable only the grant types the integration needs. Authorization-code OAuth
   is always supported. Enable client credentials for an unattended worker.
3. For an authorization-code installation, include `actor=app` in the
   authorization URL. An administrator must approve the workspace-scoped app
   installation. Do not use the deprecated `actor=application` value for a new
   integration.
4. Request the narrowest ordinary scopes that cover the worker's reads and
   mutations. Use a targeted create scope instead of broad `write` when it is
   sufficient.
5. Treat `app:assignable` and `app:mentionable` as optional capabilities. Add
   them only when users must delegate issues to or mention the app. App actors
   cannot request the `admin` scope.
6. Restrict the installed app to the intended teams. A newly minted client
   credentials token initially has access to all public teams; narrow the app's
   team access from its app details after generation and verify the effective
   result before enabling the worker.
7. Query `viewer { id name }` with the app token and record the non-secret
   workspace-specific app-user ID with the integration's credential metadata.

The application definition may be kept as a secretless manifest when that
helps reproduce display and grant-type configuration. Keep client IDs where
local policy permits non-secret integration metadata, but never commit client
secrets, authorization codes, access tokens, refresh tokens, or API keys.

## Unattended Client Credentials

Use the OAuth `client_credentials` grant for a poller or service that cannot
complete an interactive user flow. Linear issues an app-actor access token
without a refresh token; the documented lifetime is 30 days.

The service should:

- mint a token during startup or just before first use instead of treating an
  access token as permanent configuration;
- keep the client secret in a protected secret store or service credential
  facility, readable only by the owning service identity;
- keep access tokens out of command arguments, environment dumps, logs, issue
  comments, durable notes, crash reports, and metrics;
- cache a token only in protected runtime state when reuse is needed;
- on a Linear `401`, discard the rejected token, request one replacement, and
  retry the original idempotent read or safely reconciled mutation;
- stop and alert rather than looping indefinitely when replacement fails.

Scope changes are a credential event. Requesting a client-credentials token
with different scopes revokes the app's existing app-actor tokens. Rotating the
client secret also invalidates its client-credentials tokens. Plan both changes
as controlled cutovers, not invisible configuration edits.

## GraphQL And MCP

Use the same app OAuth bearer token with Linear's GraphQL API and with the
hosted Streamable HTTP MCP endpoint:

```text
Authorization: Bearer <app-oauth-access-token>
```

- GraphQL: `https://api.linear.app/graphql`
- Read-write MCP: `https://mcp.linear.app/mcp`
- Structurally read-only MCP tool surface: `https://mcp.linear.app/mcp/readonly`

The MCP endpoint accepts OAuth access tokens directly, so interactive MCP tools
and an unattended GraphQL worker can share the same visible app identity when
they are intentionally given tokens from the same per-agent application. The
client must support supplying a bearer token without replacing it through an
interactive user OAuth flow.

Do not confuse endpoint selection with token authority. The `/readonly`
endpoint exposes only read tools; a read-scoped token also prevents writes at
the API authorization layer. Prefer both when rolling back an interactive tool
to read-only operation.

## Verification And Cutover

Use a disposable issue in an intended test team. Preserve only identifiers,
timestamps, and outcomes in the validation record; do not preserve tokens or
secret-bearing request output.

1. Call `viewer { id name }` through GraphQL. Confirm the returned ID and name
   are the expected app user, not the installing administrator or agent
   operator.
2. Read one intended-team issue and attempt to read a non-granted private-team
   issue. Confirm the first succeeds and the second is absent or denied.
3. Create a disposable comment with the app token. Inspect Linear's activity
   UI or query the comment author and confirm attribution to the app user.
4. Move the disposable issue to another test status, then restore it. Confirm
   both status mutations are attributed to the app where Linear exposes actor
   history.
5. Connect to `https://mcp.linear.app/mcp` with the same app bearer token. Read
   the disposable issue and perform a reversible comment or status mutation;
   confirm the same app attribution.
6. Revoke one disposable access token and confirm it receives `401` from
   GraphQL and MCP. Mint a replacement and confirm access returns without
   widening team permissions.
7. In a separate rotation rehearsal, rotate the client secret and confirm the
   old client-credentials token and old secret no longer work before updating
   the service's protected credential.
8. Remove test comments and restore the issue's original status when the test
   environment permits cleanup.

Keep manual comment signatures only until app attribution is proven. Once the
author and activity history show the correct app user, remove signatures from
routine automation so one authoritative actor identity is presented.

## Revocation, Rotation, And Rollback

Maintain non-secret credential metadata for each agent: application name,
workspace app-user ID, owner, scopes, team grants, secret-store category,
rotation date, and revocation procedure. Never copy the credential value or a
private host path into shared notes.

For routine rotation, mint and validate a replacement token before retiring
the old token when Linear's same-scope parallel-token behavior permits it.
Changing scopes or rotating the client secret invalidates existing tokens, so
stop the worker, apply the change, install the replacement secret, re-run the
identity and access checks, then restart it.

For immediate revocation, stop the worker and interactive clients, revoke the
token or remove the app's team/workspace access, and verify rejected GraphQL
and MCP requests. Rotate the client secret if its confidentiality may have been
lost. Inspect recent app-authored mutations before restoring service.

If app attribution or authorization is wrong, fail closed:

1. Stop writes and preserve non-secret validation evidence.
2. Remove the app token from workers and MCP clients.
3. Continue essential inspection through the read-only MCP endpoint with a
   read-scoped user OAuth session, or pause automation entirely.
4. Use a personal API key or email-backed member/guest only as an explicit,
   time-bounded fallback. Record that actions will be attributed to that human
   account and revoke the fallback credential after recovery.
5. Correct the app installation, scopes, and team grants; repeat the full
   verification sequence before restoring writes.

## Developer Preview Boundary

Linear's app actor authorization and ordinary app-authored issue, comment, and
status mutations are documented in the standard OAuth guidance. They do not
require the agent-session interaction model.

Linear for Agents APIs are separately marked Developer Preview. Treat agent
session events, activity streaming, mention-triggered sessions, and delegation
workflows as preview capabilities whose contracts may change. The optional
`app:mentionable` and `app:assignable` scopes belong to that interaction shape;
omit them when a background worker only polls and performs ordinary API
mutations.

## Official References

- [OAuth actor authorization](https://linear.app/developers/oauth-actor-authorization)
- [OAuth 2.0 authentication](https://linear.app/developers/oauth-2-0-authentication)
- [OAuth application manifests](https://linear.app/developers/oauth-app-manifests)
- [Linear for Agents: Getting Started](https://linear.app/developers/agents)
- [AI Agents in Linear](https://linear.app/docs/agents-in-linear)
- [Linear MCP server](https://linear.app/docs/mcp)
