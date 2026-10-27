# Claude Code plugins in Docker Sandboxes: setup from scratch

How to set up a fresh machine so that Claude Code runs inside a Docker Sandbox
(`sbx`) with exactly the plugins a project pins, and nothing else.

Tested on macOS 26 (Apple silicon) with sbx v0.49.2, Claude Code 2.1.306
inside the sandbox, and cs-plugin 0.1.1 run from its GitHub release tag. Linux notes are in
step 2.

## How it fits together

| Piece | What it does |
|---|---|
| `plugins.toml` | the project's plugin list, each pinned to a release, committed to git |
| `cs-plugin` | turns `plugins.toml` into files Claude Code reads (`add`, `upgrade`, …), and installs exactly those plugins (`sync`) |
| `sbx` | runs Claude Code in an isolated VM, with the project folder mounted at the same path |

The sandbox has its own `~/.claude` and never sees the plugins installed on your
laptop. It does see the project folder. So you **choose plugins on the laptop**
(edit and commit `plugins.toml`) and **install them inside the sandbox**
(`cs-plugin sync`).

> cs-plugin is not on PyPI yet. Every `cs-plugin` command below runs it with
> uv straight from its GitHub release tag, `pkg-cs-plugin--v0.1.1`. To move to
> a newer release, change the tag. Once it is on PyPI, `uvx cs-plugin@<version>`
> will do.

---

## 1. Install uv on the laptop

uv runs `cs-plugin` without installing it, and fetches the Python it needs.
The first run builds cs-plugin from GitHub, which takes a few seconds; later
runs use uv's cache.

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
# open a new terminal, then:
uv --version
```

Make a shortcut for this terminal session (add it to `~/.zshrc` or `~/.bashrc`
to keep it):

```sh
alias cs-plugin='uvx --from "git+https://github.com/ubyndr/cs-plugin@pkg-cs-plugin--v0.1.1#subdirectory=packages/cs-plugin" cs-plugin'
cs-plugin --version        # cs-plugin 0.1.1
```

You do **not** need Claude Code on the laptop for this guide; it runs inside
the sandbox.

## 2. Install sbx

Docker Desktop is **not** needed. Open the section for your system:

<details>
<summary><strong>macOS (Apple silicon)</strong></summary>

```sh
brew tap docker/tap
brew install --cask docker/tap/sbx
sbx version
```

</details>

<details>
<summary><strong>Linux</strong></summary>

sbx starts a small VM per sandbox, so you need hardware virtualization and
access to `/dev/kvm`:

```sh
ls -l /dev/kvm                       # must exist
sudo usermod -aG kvm "$USER"         # then log out and back in
id -nG | grep -w kvm                 # must print kvm
```

- **Ubuntu 24.04 or later:**
  ```sh
  curl -fsSL https://get.docker.com | sudo REPO_ONLY=1 sh
  sudo apt install docker-sbx
  ```
- **Ubuntu 22.04 and other distros:** the apt package does not exist
  (`E: Unable to locate package docker-sbx`). Use the tarball, which installs
  for your user only. Docker does not officially support sbx on these.
  ```sh
  curl -LO https://github.com/docker/sbx-releases/releases/latest/download/DockerSandboxes-linux-amd64.tar.gz
  tar -xzf DockerSandboxes-linux-amd64.tar.gz
  ./docker-sbx/install.sh                          # installs to ~/.docker/sbx
  export PATH="$HOME/.docker/sbx/bin:$PATH"        # also add to ~/.bashrc
  sbx version
  ```

</details>

## 3. Sign in to Docker

```sh
sbx login
```

This prints a code and a link; open the link and approve. You need a Docker
account (free for local sandboxes).

If it fails with `"access_denied" "Global rate limit exceeded"`, Docker's
sign-in service is throttling. Either wait 10–15 minutes and try once more, or
sign in with a [personal access token](https://app.docker.com/settings/personal-access-tokens)
instead (the token is read without being shown):

```sh
read -s DOCKER_PAT && echo "$DOCKER_PAT" | sbx login --username <your-docker-id> --password-stdin; unset DOCKER_PAT
```

Check: `sbx ls` prints `No sandboxes found` (not `not signed in`).

## 4. Set the network policy (once per machine)

Sandboxes block all outbound traffic that a rule does not allow. Start from
Docker's **balanced** preset, which already allows the Anthropic API, GitHub
(where cs-plugin and the plugins come from), PyPI and astral.sh, then add what
plugin installs and the plugins themselves need:

```sh
sbx policy init balanced
sbx policy allow network "releases.astral.sh,release-assets.githubusercontent.com,claude.ai,celltype.info"
```

| Domain | Why |
|---|---|
| `releases.astral.sh`, `release-assets.githubusercontent.com` | uv fetching tools and Python |
| `claude.ai` | signing Claude Code in, inside the sandbox |
| `celltype.info` | what the `cap-tools` plugin talks to |

These rules apply to **every sandbox on this machine**, for every project, and
stay until you remove them, so you do this step once, not per project or
sandbox. Come back to it only when a new plugin needs a domain that is not
allowed yet. To allow a domain for one sandbox only, add
`--sandbox <name>`:

```sh
sbx policy allow network --sandbox my-project example.org
```

`sbx policy ls` shows what applies where: `local-policy` (applies to `all`)
holds the rules above; the per-sandbox `kit` policies are the Claude domains
each `claude` sandbox gets automatically, which you do not need to add.

Check a domain at any time:

```sh
sbx policy check network github.com      # Allowed: github.com:443
```

## 5. Get the project

**Joining an existing project:** clone it. Its `plugins.toml` and `.claude/`
folder are already committed.

```sh
git clone <project-url> ~/github/my-project
cd ~/github/my-project
```

**Starting a new one:** pin plugins with cs-plugin, then commit.

```sh
mkdir -p ~/github/my-project && cd ~/github/my-project && git init
cs-plugin list                                   # what is available
cs-plugin add cap-tools@0.4.0                    # a version; or just the name for the newest
git add -A && git commit -m "Pin Claude Code plugins"
```

That writes:

| File | What it is |
|---|---|
| `plugins.toml` | the pins, the file you read and edit |
| `.claude/cs-plugin/` | the project's own plugin marketplace, generated from `plugins.toml` |
| `.claude/settings.json` | tells Claude Code to use that marketplace and its plugins |
| `.gitignore` | ignores `.claude/settings.local.json`, which holds a machine-specific path |

## 6. Create the sandbox

From the project folder:

```sh
sbx create --name my-project claude .
sbx ls            # my-project   claude   ● running   /Users/you/github/my-project
```

The folder is mounted at **the same path** inside the sandbox. The sandbox runs
as user `agent`, with `git`, Python, Node, Claude Code and `uv` already there.

## 7. Install the pinned plugins inside the sandbox

From the project folder on the laptop:

```sh
sbx exec -e PROJ="$PWD" my-project bash -lc 'cd "$PROJ" && uv tool run --from "git+https://github.com/ubyndr/cs-plugin@pkg-cs-plugin--v0.1.1#subdirectory=packages/cs-plugin" cs-plugin sync'
```

`-e PROJ="$PWD"` passes the project's path into the sandbox, where it is the
same path. Use `uv tool run` here: the sandbox has `uv` but not the `uvx`
shortcut. The double quotes around the `git+…` address sit inside the single
quotes, so they reach the sandbox intact.

This one command is the whole install. `sync` reads `plugins.toml` and the
generated `.claude/` files and runs `claude plugin install` for each pinned
plugin at its pinned tag. Nothing else needs installing: the CLIs the skills
call (such as `cap` for `cap-tools`) are fetched by uv the first time a skill
uses them. Everything stays in the sandbox until `sbx rm`.

Expected output ends with one `ok` line per plugin:

```
ok  cap-tools 0.4.0
```

## 8. Check it worked

```sh
sbx exec -e PROJ="$PWD" my-project bash -lc 'cd "$PROJ" && claude plugin list'
```

Each pinned plugin shows `Scope: project` and the pinned version. Your laptop's
own `~/.claude` is not changed by any of this.

Plugins listed under `Synced from claude.ai` come from your Claude account or
organisation, not from this project. They load once Claude is signed in
(step 9) and are managed in claude.ai, not by cs-plugin.

Then run `git status` on the laptop: `sync` leaves the committed files
unchanged.

## 9. Use Claude and the plugins' skills in the sandbox

### Sign Claude in (once per sandbox)

The sandbox does not share the laptop's sign-in. Check, then sign in:

```sh
sbx exec my-project claude auth status        # "loggedIn": false until you sign in
sbx run --name my-project                     # then type /login and finish in the browser
```

The sign-in is kept inside the sandbox until `sbx rm`. To use an API key
instead, store it with `sbx secret set anthropic`: sbx adds it to requests as
they leave the sandbox, so the key itself never enters it.

### Interactive session

```sh
cd ~/github/my-project
sbx run --name my-project
```

Inside Claude, either describe what you want and let Claude pick the skill, or
call a skill by name as `/<plugin>:<skill>`:

```
List Human Cell Atlas datasets on CAP
/cap-tools:cap-datasets list Human Cell Atlas datasets
```

- Type `/` to see the available skills, or `/plugin` to see the installed
  plugins. With `cap-tools` pinned, the skills are `cap-datasets`,
  `cap-degs`, `cap-feedback` and `cap-gene-expression`.
- sbx starts Claude with permission prompts turned off
  (`--dangerously-skip-permissions`). The sandbox's isolation and network
  policy are the safety boundary instead.
- Exit Claude to leave. The sandbox keeps running; `sbx stop my-project` stops
  it, and everything installed survives until `sbx rm`.

### One-shot from the laptop's terminal

To run a single prompt without opening a session (for scripted checks or batch
runs), use Claude Code's print mode inside the sandbox:

```sh
cd ~/github/my-project
sbx exec -e PROJ="$PWD" my-project bash -lc 'cd "$PROJ" && claude -p --dangerously-skip-permissions "/cap-tools:cap-datasets list Human Cell Atlas datasets"'
```

Claude runs the prompt, uses whatever skills and tools it needs, prints the
answer and exits.

The part that runs on the laptop:

| Piece | Meaning |
|---|---|
| `sbx exec` | Run one command inside an existing sandbox, then return. Unlike `sbx run`, it does not open an interactive session. |
| `-e PROJ="$PWD"` | Set an environment variable inside the sandbox. `$PWD` is expanded on the laptop, so `PROJ` becomes the project's path, which is the same path inside the sandbox. |
| `my-project` | Which sandbox, the name given to `sbx create --name`. |
| `bash -lc '…'` | Start bash inside the sandbox and run the quoted text. `-l` loads the sandbox user's profile so `claude` and `uv` are on PATH; `-c` runs the string. |

Keep the single quotes: everything inside `'…'` reaches the sandbox
unexpanded, so `"$PROJ"` is filled in there, from the value `-e` set. With
double quotes, the laptop's shell would expand `$PROJ` first, where it is not
set.

The part that runs inside the sandbox:

| Piece | Meaning |
|---|---|
| `cd "$PROJ"` | Go to the project folder. The plugins are installed for this project only, so Claude must start here to see them. |
| `&&` | Start Claude only if the `cd` succeeded. |
| `claude -p` | Print mode: no interactive interface; process the one prompt, print the final answer, exit. |
| `--dangerously-skip-permissions` | Run tools without asking. In print mode nobody is there to approve, so without it Claude could not run the skill's commands. Acceptable here because the sandbox is the safety boundary. Claude Code refuses it as root; the sandbox runs as user `agent`. |
| `"/cap-tools:cap-datasets …"` | The prompt. `/cap-tools:cap-datasets` invokes that skill explicitly; the rest is the request. A plain-language request works too. |

Add `--output-format json` after `-p` for a structured result (answer, cost,
duration, session ID) when a script reads the output.

[`scripts/sbx-claude.sh`](scripts/sbx-claude.sh) wraps this command
(`./scripts/sbx-claude.sh [--json] my-project "<prompt>"`), and
[examples/](examples/) has prompts run this way with their recorded output.

### Testing a tool without Claude

Each skill's `SKILL.md` tells Claude to run a pinned
`uvx --from "git+…@<tag>…" <command>` line. Running that line yourself in the
sandbox (as `uv tool run --from …`) checks the tool and the network policy
without using Claude. It does not test whether Claude chooses and uses the skill
well; the two options above do.

For `cap-tools`, that tool is the `cap` CLI:

```sh
sbx exec my-project bash -lc 'uv tool run --from "git+https://github.com/Cellular-Semantics/cap_skills@v0.4.0#subdirectory=packages/cap-client" cap datasets --consortium "Human Cell Atlas" --format text'
```

[examples/03-cap-cli.md](examples/03-cap-cli.md) shows how to find the tag,
define a `cap` shortcut in a sandbox shell, and what the output looks like.

## 10. Changing plugins later

On the laptop:

```sh
cs-plugin outdated                 # pins with a newer release
cs-plugin upgrade cap-tools        # or: add NAME, remove NAME
git commit -am "Update plugin pins"
```

Then re-run step 7 to install the change in the sandbox, and restart Claude
(`sbx run --name my-project`). A co-worker who pulls the change does the same.

## 11. Cleaning up

```sh
sbx rm my-project          # deletes the sandbox and its plugin installs; the project folder stays
```

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `E: Unable to locate package docker-sbx` | not Ubuntu 24.04+; use the tarball in step 2 |
| `error: not signed in to Docker` | step 3 |
| `Global rate limit exceeded` on login | Docker's sign-in throttling; wait, or use a token (step 3) |
| `global network policy has not been initialized` | `sbx policy init balanced` (step 4) |
| a download fails or hangs inside the sandbox | blocked by policy: `sbx policy log` shows what was denied, then `sbx policy allow network <host>` |
| `uvx: command not found` inside the sandbox | use `uv tool run …` instead |
| `.claude/settings.json` shows as modified | Claude Code rewrites this file in its own key order when it installs plugins. cs-plugin 0.1.1+ puts the committed text back after `sync`; with an older version, or after installing plugins by hand, check `git diff` shows only reordering, then `git checkout -- .claude/settings.json`. |
| `the generated files do not match plugins.toml` | `plugins.toml` was edited by hand; run `cs-plugin generate` on the laptop and commit |
| `atlas-tools … is a bundle` | add the plugins it names instead; bundles would install unpinned |
| `sbx` fails to start a sandbox on Linux | check `/dev/kvm` access (step 2) and run `sbx diagnose` |

## Reference

- cs-plugin: https://github.com/ubyndr/cs-plugin (releases are tagged `pkg-cs-plugin--v<version>`)
- Docker Sandboxes: https://docs.docker.com/ai/sandboxes/
- sbx releases: https://github.com/docker/sbx-releases
