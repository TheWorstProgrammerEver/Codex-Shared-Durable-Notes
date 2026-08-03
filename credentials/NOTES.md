# Credential Notes

Do not store secrets, private keys, tokens, passwords, recovery codes, Wi-Fi
credentials, OAuth refresh tokens, app passwords, or full credential values in
durable notes.

Protected storage is not the authorization boundary for a model-controlled
runtime. When an agent needs to exercise a third-party credential, use
`runbooks/secretless-agent-integrations.md`: keep the credential in a connector
and authorize each typed effect and its concrete arguments. Do not expose a
token-returning vault or credential helper to the agent.

Record only:

- purpose;
- owner;
- scope;
- storage location;
- file permissions;
- owning service or workflow;
- how to revoke, rotate, or delete the credential;
- when the metadata was last validated.

## Metadata Template

Use this shape for local credentials:

```text
## Service Or Workflow Name

Date:

- Purpose:
- Owner:
- Scope:
- Secret storage location:
- Expected permissions:
- Owning service or command:
- Plaintext value recorded here: no.
- Revocation:
- Rotation:
- Validation:
```

## Common Patterns

GitHub App:

- Prefer a GitHub App installation over a personal access token.
- Store the private key in a protected local config directory.
- Mint short-lived installation tokens on demand.
- Revoke by suspending or uninstalling the app, or by rotating the private key.

Linear app-user OAuth:

- When a durable agent or unattended worker needs distinct visible authorship,
  prefer one private OAuth app and app user per agent identity. Follow
  [Linear Agent Identity](../runbooks/linear-agent-identity.md).
- Authorize the app with `actor=app`. Use a direct app bearer token for Linear
  MCP and GraphQL, and use the client-credentials grant for unattended workers.
- Limit scopes and team grants, keep client secrets and access tokens in
  protected credential state, and verify `viewer` before enabling writes.
- Revoke the token or app installation, or rotate the client secret, then
  repeat the identity and authorization checks before restarting the worker.

User-authenticated Linear MCP fallback:

- Use user OAuth only when the workflow intentionally acts as the signed-in
  human or the MCP client cannot accept an app bearer token.
- Record that mutations are attributed to that human; this credential does not
  create a distinct agent actor.
- Store token material only in Codex-managed private state. Revoke it in Linear
  account or workspace settings, then re-run MCP login when required.

Personal Linear API key fallback:

- Use a dedicated personal API key only as an explicit, time-bounded fallback
  for a workflow intentionally acting as the key's human owner.
- Do not treat a separate API key as a separate agent identity. Store it in
  ignored local configuration or a protected service environment file.
- Revoke it in Linear account API settings and restart the owning service only
  after replacement and attribution checks pass.

Mailbox or notification bot:

- Store provider tokens only in protected local configuration.
- Keep recovery controls with the human operator.
- Revoke at the provider, then remove or replace the local secret file.
