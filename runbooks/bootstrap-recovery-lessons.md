# Bootstrap Failure And Recovery Lessons

Fresh-host bootstrap should be supervised until it has succeeded on real
hardware. Dry-runs and idempotence checks are valuable, but first boot exposes
networking, image, firmware, package, and credential assumptions.

## Two-Phase Bootstrap

Use a simple first phase to install minimum prerequisites:

- package updates;
- git;
- runtime dependencies;
- Codex CLI;
- bootstrap skills or setup repository;
- optional SSH/tmux primitives.

Then let Codex or the setup framework complete higher-level configuration using
runbooks and skills.

## Codex Npm Runtime Path

Fixing npm's global prefix and an interactive shell's `PATH` does not prove that
a non-login service or timer can launch Codex. For the target service account:

- confirm `npm config get prefix`, `command -v codex`, and `codex --version`
  interactively;
- configure the service `PATH` with the user-owned npm global `bin` directory
  before root-owned binary directories, or set `CODEX_BIN` to the resolved
  absolute Codex executable path;
- do not rely on shell startup files or unverified `$HOME` expansion in a
  generated unit or environment file.

Exercise the same lookup with a minimal non-login environment. For example:

```bash
USER_NPM_BIN="$(npm config get prefix)/bin"
env -i PATH="${USER_NPM_BIN}:/usr/local/bin:/usr/bin:/bin" \
  sh -c 'command -v codex && codex --version'

CODEX_BIN="$(command -v codex)"
env -i CODEX_BIN="${CODEX_BIN}" PATH=/usr/bin:/bin \
  sh -c 'test -x "$CODEX_BIN" && "$CODEX_BIN" --version'
```

Run this validation as the account used by the service. If the real unit still
fails, inspect its effective environment and executable resolution rather than
assuming the interactive shell result applies.

## Image And Media Validation

When preparing removable boot media:

- verify the downloaded image checksum;
- verify the write when practical;
- run read-only filesystem checks after customization;
- keep local-only configuration out of public repos;
- document the exact image family and setup method that worked.

## Network First Boot

Do not assume a headless machine has network access. Validate the OS-specific
first-boot network mechanism.

For Raspberry Pi OS Lite ARM64 Trixie, cloud-init NoCloud reads first-boot
network configuration from the boot partition. A Netplan v2 `network-config`
file is the reusable shape for Wi-Fi provisioning on that image family.

## Secrets

Do not bake these into images or public repositories:

- Codex auth;
- GitHub App private keys;
- GitHub tokens;
- Linear OAuth tokens;
- API keys;
- private SSH keys;
- Wi-Fi credentials;
- initial plaintext passwords.

Use local-only configuration files, prompts, or operator handoffs, and record
only metadata in durable notes.

## Recovery Signals

Bootstrap scripts and services should leave inspectable state:

- systemd unit status;
- journal logs;
- setup logs;
- durable notes or handoff files;
- clear retry commands;
- clear cleanup commands when a partial setup is safe to remove.

Prefer a failed but inspectable setup over a script that hides errors or loops
forever.
