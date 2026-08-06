# Headless Operator Flows

Headless agent hosts need predictable operator handoffs for offline network
recovery, SSH access, tmux attachment, and browser-based OAuth.

## Offline Network Recovery

Local recovery availability is a separate readiness requirement from ordinary
SSH access. Before deploying or relocating a host:

- Preserve and test a local console and local login that do not depend on the
  current network path. Keep their host-specific details out of shared notes.
- Ship the recovery tool, required runtime, network backend, and platform
  instructions on the image. The flow must not need DNS, upstream access, or a
  package download.
- Read network secrets only through hidden input from the controlling terminal.
  Do not place them in arguments, environment variables, shell history, logs,
  state files, or diagnostic output.
- Give the smallest privileged helper sole ownership of network-profile writes.
  Replace profiles atomically with the platform's privileged owner and
  private-only permissions (for example, owner `root` and mode `0600` on
  POSIX systems).
- Emit constant, redacted status messages and stable error codes. Do not expose
  entered values, raw subprocess output, or profile contents on success or
  failure.
- Make the apply boundary explicit: write and validate the profile, ask for
  operator confirmation when appropriate, then reload or restart the network
  service. Verify local link and address readiness before testing SSH; lack of
  upstream Internet access must not make local recovery appear to have failed.
- Isolate recovery from resumable agent state. A network retry may touch only
  its owned profile and network service; it must not delete, reset, advance, or
  reinterpret unrelated job checkpoints.

Keep exact commands and service names in the image or platform implementation
documentation, and link that documentation from the host-local operator note.
Do not copy platform-specific commands into this shared runbook. For one Linux
image implementation, see the
[Agent Boot Image CLI network-reconfiguration guide](https://github.com/TheWorstProgrammerEver/Agent-Boot-Image-CLI/blob/main/docs/operator/network-reconfiguration.md).

## SSH Access

- Install and enable SSH only when the host is intended for remote operation.
- Add the operator's public key through a deliberate bootstrap step.
- Prove every intended key path before a key-only cutover. Use the
  [appliance runbook's transactional SSH gate](agent-appliance-provisioning.md#field-proven-gates)
  to check effective target-user policy and separate password and
  keyboard-interactive negative probes.
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

## Temporary Removable-Media Browsing

When an operator needs Finder or another SMB client to browse attached media,
use the
[temporary removable-media SMB runbook](temporary-removable-media-smb.md).
Keep the partition and SMB export independently read-only, require temporary
authentication and encryption, and tear down the listener before unmounting
the media.
