# Credential Notes

Do not store secrets, private keys, tokens, passwords, recovery codes, Wi-Fi
credentials, OAuth refresh tokens, app passwords, or full credential values in
durable notes.

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

Linear MCP OAuth:

- Use OAuth for interactive Codex sessions.
- Store token material only in Codex-managed private state.
- Revoke in Linear account or workspace settings, then re-run MCP login.

Linear API key:

- Use a dedicated key for unattended local pollers.
- Store it in ignored local configuration or a protected service environment
  file.
- Revoke in Linear account API settings and restart the owning service after
  replacement.

Mailbox or notification bot:

- Store provider tokens only in protected local configuration.
- Keep recovery controls with the human operator.
- Revoke at the provider, then remove or replace the local secret file.
