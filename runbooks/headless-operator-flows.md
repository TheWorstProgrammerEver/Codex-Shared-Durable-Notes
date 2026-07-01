# Headless Operator Flows

Headless agent hosts need predictable operator handoffs for SSH access, tmux
attachment, and browser-based OAuth.

## SSH Access

- Install and enable SSH only when the host is intended for remote operation.
- Add the operator's public key through a deliberate bootstrap step.
- Confirm key-based login before disabling password login.
- Disable root SSH login.
- Restrict SSH users when appropriate.
- Keep local access instructions in a host-local note, not in a shared repo.

## Persistent Sessions

Use tmux or an equivalent terminal multiplexer so the operator can attach to the
agent's ongoing session after network drops or workstation restarts.

Useful local conventions:

- one stable attach command;
- one named default session;
- a small root-level access note pointing to details;
- no secrets in shell banners or attach helpers.

## Browser OAuth On Headless Hosts

Many CLI OAuth flows start a localhost callback server on a random port. On a
headless host:

1. start the login command on the agent host;
2. note the printed callback port;
3. open an SSH local port forward from the workstation to the agent host for
   that same port;
4. open the authorization URL in the workstation browser;
5. confirm the CLI reports successful login;
6. remove the tunnel when finished.

Generic tunnel shape:

```bash
ssh -L <callback-port>:127.0.0.1:<callback-port> <agent-user>@<agent-host>
```

Do not store OAuth tokens in durable notes or reusable images. Record only the
service purpose, config location, credential storage location, owner, scope, and
revocation path.

## Operator File Drop Zone

If the operator sends files over SSH, keep an explicit local inbox with narrow
permissions and a cleanup routine:

- incoming files;
- files currently being processed;
- short-term archive for useful artifacts;
- explicit deletion of disposable files after use.

Do not let the inbox become the durable knowledge base. Promote only reusable
facts into durable notes.
