# Troubleshooting

Problems seen while following [GUIDE.md](GUIDE.md), and how to fix them.

## Network policy

### Checking which policy a machine has

```sh
sbx policy ls
sbx policy inspect local-policy | grep default-
```

On a machine set up with `balanced`, `local-policy` (applies to `all`) shows
about 195 network allows, and the inspect lists these rule IDs:

```
default-ai-services
default-package-managers
default-code-and-containers
default-cloud-infrastructure
default-os-packages
default-cert-validation
default-fs-read-allow-all
default-fs-write-allow-all
```

If `local-policy` has only a handful of network allows, and only the two
`default-fs-*` IDs, the machine was set up with `deny-all` (or the balanced
rules were removed). Everything outside those few hosts is blocked, including
GitHub, PyPI and Docker Hub.

### `global network policy is already initialized; reset it first to change it`

`sbx policy init` runs only once per machine. If you set up sandboxes before
this guide, the machine already has a policy, possibly `deny-all` or
`allow-all`, and `sbx policy init balanced` refuses to change it.

If `sbx policy inspect local-policy | grep default-` already lists the
`default-*` network IDs above, the machine is on `balanced`: ignore the error
and carry on with the `sbx policy allow network …` line in step 4.

Otherwise, switch to `balanced` with
[scripts/sbx-policy-rebalance.sh](scripts/sbx-policy-rebalance.sh). Changing the
preset needs `sbx policy reset`, which deletes **every** local rule (global and
per-sandbox), so the script saves your own rules first and adds them back.
It does not need a project; download it if you have not cloned this
repository:

```sh
mkdir -p scripts
curl -fsSL -o scripts/sbx-policy-rebalance.sh https://raw.githubusercontent.com/Cellular-Semantics/sbx-plugin-guide/main/scripts/sbx-policy-rebalance.sh
chmod +x scripts/sbx-policy-rebalance.sh

scripts/sbx-policy-rebalance.sh --dry-run   # lists the rules it will add back; changes nothing
scripts/sbx-policy-rebalance.sh             # asks y/N, then resets, inits balanced, re-adds
```

- The reset **stops running sandboxes**; sbx asks before it does.
- After the reset, sbx may ask you to pick a policy itself. Pick **balanced**.
- Your old rules are saved to `~/sbx-policy-backup-<timestamp>.json`.
- `kit` policies (the Claude domains of each `claude` sandbox) are not touched;
  sbx recreates them.
- A rule the script cannot copy (for example one limited to HTTP methods or
  paths) is reported as `skipped rule …`; add it back by hand from the backup.

Then add this project's domains if they were not among your old rules (step 4).

### The script stopped before adding my rules back

If the reset and init went through but the rules were not re-added, add them
from the backup:

```sh
ls ~/sbx-policy-backup-*.json
scripts/sbx-policy-rebalance.sh --restore ~/sbx-policy-backup-<timestamp>.json
```

### Doing it by hand

```sh
sbx policy ls --source local --type network --json > ~/sbx-policy-backup.json   # keep your rules
sbx policy reset
sbx policy init balanced
sbx policy allow network "<host>,<host>"                    # your global rules
sbx policy allow network --sandbox <name> "<host>"          # your per-sandbox rules
```

### `Denied: github.com:443 … no matching allow rule (default deny)`

The machine is not on `balanced`; see [Checking which policy a machine
has](#checking-which-policy-a-machine-has). To unblock just GitHub without a
reset:

```sh
sbx policy allow network "github.com,*.github.com,*.githubusercontent.com"
```

### `global network policy has not been initialized`

Run `sbx policy init balanced` (GUIDE step 4).

### A download fails or hangs inside the sandbox

It is blocked by the policy. `sbx policy log` shows what was denied; allow it
with `sbx policy allow network <host>`, or `sbx policy check network <host>`
to test first.

## Installing and signing in

| Symptom | Cause and fix |
|---|---|
| `E: Unable to locate package docker-sbx` | not Ubuntu 24.04+; use the tarball in GUIDE step 2 |
| `error: not signed in to Docker` | GUIDE step 3 |
| `Global rate limit exceeded` on login | Docker's sign-in throttling; wait, or use a token (GUIDE step 3) |
| `sbx` fails to start a sandbox on Linux | check `/dev/kvm` access (GUIDE step 2) and run `sbx diagnose` |

## Plugins

| Symptom | Cause and fix |
|---|---|
| `uvx: command not found` inside the sandbox | use `uv tool run …` instead |
| `.claude/settings.json` shows as modified | Claude Code rewrites this file in its own key order when it installs plugins. cs-plugin 0.1.1+ puts the committed text back after `sync`; with an older version, or after installing plugins by hand, check `git diff` shows only reordering, then `git checkout -- .claude/settings.json`. |
| `the generated files do not match plugins.toml` | `plugins.toml` was edited by hand; run `cs-plugin generate` on the laptop and commit |
| `atlas-tools … is a bundle` | add the plugins it names instead; bundles would install unpinned |
