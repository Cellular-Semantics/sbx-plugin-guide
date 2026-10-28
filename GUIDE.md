# Claude Code plugins in Docker Sandboxes: setup from scratch

How to set up a fresh machine so that Claude Code runs inside a Docker Sandbox
(`sbx`), in **any project of your own**, with exactly the plugins you pin for
that project, and nothing else.

You do not need to clone this repository. It is the guide and a worked example;
everything below happens in your own project folder.

Tested on macOS 26 (Apple silicon) with sbx v0.49.2, Claude Code 2.1.306
inside the sandbox, and cs-plugin 0.1.1 run from its GitHub release tag. Linux notes are in
step 2.

## How it fits together

| Piece | What it does |
|---|---|
| `cs-plugin` | pins plugins for a project (`add`, `upgrade`, `remove`), and installs exactly those plugins (`sync`) |
| `plugins.toml` | the project's plugin list, each pinned to a release; `cs-plugin add` creates it in your project |
| `sbx` | runs Claude Code in an isolated VM, with the project folder mounted at the same path |

The sandbox has its own `~/.claude` and never sees the plugins installed on your
laptop. It does see the project folder. So you **choose plugins on the laptop**
(`cs-plugin add`, which writes `plugins.toml` and `.claude/` into your project)
and **install them inside the sandbox** (`cs-plugin sync`).

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

> **Already used sbx on this machine?** Then it already has a policy, and
> `sbx policy init balanced` fails with `global network policy is already
> initialized`. Check which one with
> `sbx policy inspect local-policy | grep default-`: if it lists
> `default-code-and-containers` and the other `default-*` network rules, you are
> on balanced; skip the init and run the `allow` line. If not (for example the
> machine was set up with `deny-all`), switch with
> [`sbx-policy-rebalance.sh`](scripts/sbx-policy-rebalance.sh), which keeps
> your existing rules. See
> [TROUBLESHOOTING.md](TROUBLESHOOTING.md#network-policy).

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

## 5. Add plugins to your project with cs-plugin

Go to your project's folder on the laptop. Any project works: an existing
repository with its own code, or a new empty folder.

```sh
cd ~/github/my-project          # your project
cs-plugin list                  # the plugins available, with their releases
cs-plugin add cap-tools@0.4.0   # pin a release; or just `cap-tools` for the newest
```

`add` writes these into the project, next to your own files:

| File | What it is |
|---|---|
| `plugins.toml` | the pins, the file you read; change it with `cs-plugin add/remove/upgrade` |
| `.claude/cs-plugin/` | the project's own plugin marketplace, generated from `plugins.toml` |
| `.claude/settings.json` | tells Claude Code to use that marketplace and its plugins |
| `.gitignore` | one line for `.claude/settings.local.json`, which holds a machine-specific path (git repositories only) |

If the project already has a `.claude/settings.json`, `add` keeps what is in it
and adds two keys, `extraKnownMarketplaces` and `enabledPlugins`. Check with
`git diff`. Your code and other files are not touched.

Add more plugins the same way (`cs-plugin add NAME …`). Then commit, so
co-workers and other machines get the same pins:

```sh
git add plugins.toml .claude .gitignore
git commit -m "Pin Claude Code plugins"
```

**Joining a project that already pins plugins** (it has a `plugins.toml`): skip
`add`; clone or pull it and go on to step 6.

## 6. Create the sandbox

From the project folder (`my-project` is the sandbox's name; any name works):

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

This one command is the whole install. `sync` reads the `plugins.toml` and
`.claude/` files that step 5 wrote and runs `claude plugin install` for each pinned
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

[`scripts/sbx-claude.sh`](scripts/sbx-claude.sh) in this repository wraps this
command (`sbx-claude.sh [--json] my-project "<prompt>"`; copy it into your
project or onto your PATH), and [examples/](examples/) has prompts run this way
with their recorded output.

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

## 10. Secrets: API keys, tokens and MCP keys

Keep secrets **out of the project folder**: it is mounted into the sandbox and
may be committed. Store them on the laptop with `sbx secret` instead. sbx keeps
them in its secret store on the laptop (the system keychain), and its proxy
adds them to requests as they leave the sandbox. Inside the sandbox, the
matching environment variable holds only a placeholder, so Claude, the plugins
and anything else running there never see the real value.

### Built-in services: GitHub, Anthropic, OpenAI, …

sbx knows these services: `anthropic`, `copilot`, `cursor`, `devin`, `droid`,
`github`, `google`, `groq`, `mistral`, `nebius`, `openai`, `openrouter`, `xai`.

For example, a GitHub personal access token. Run **one** of these:

- **Paste a token.** sbx asks for it and does not show it:

  ```sh
  sbx secret set github --sandbox my-project
  ```

- **Or, if you use the GitHub CLI,** let sbx take the token from `gh` each
  time it needs one, so there is nothing to paste:

  ```sh
  sbx secret set github --sandbox my-project --command 'gh auth token'
  ```

`--sandbox my-project` gives the token to that sandbox only. Leave it out to
share the token with every sandbox on this machine (see the scopes below).

Never put the token itself on the command line, as in
`echo "ghp_…" | sbx secret set github` or `--token ghp_…`: the shell saves the
whole line, token included, in its history file (`~/.zsh_history`,
`~/.bash_history`). If that happened, revoke the token on GitHub and delete the
line from the history file.

Inside the sandbox, `GH_TOKEN` is set to a placeholder
(`gho_sbxproxymanaged000…`); `gh`, `git` and other tools use it as usual, and
the proxy swaps in your token on requests to GitHub. To check:

```sh
sbx exec my-project bash -lc 'echo "$GH_TOKEN"; curl -s https://api.github.com/user'
```

`"Requires authentication"` means no GitHub token is stored for that sandbox.
Restart a running sandbox (`sbx stop my-project`, then `sbx run --name
my-project`) after adding or changing a secret.

For Claude itself, signing in with `/login` (step 9) is usually enough; to use
an API key instead, `sbx secret set anthropic`.

### Other APIs and MCP servers: custom secrets

For a service sbx does not know, such as an API an MCP server calls, use
`set-custom` (experimental in sbx v0.49). You give the host the key is for and
the environment variable to put the placeholder in:

```sh
read -rs EXAMPLE_KEY                        # paste the key; it is not shown or saved in history
sbx secret set-custom --sandbox my-project \
  --host api.example.com --env EXAMPLE_API_KEY --value "$EXAMPLE_KEY"
unset EXAMPLE_KEY
```

Inside the sandbox, `EXAMPLE_API_KEY` holds the placeholder, and the proxy
replaces it with the key in the **headers** of requests to `api.example.com`.
So it works for keys sent in a header (such as `Authorization: Bearer …`),
not for keys put in a URL or request body. The host must also be allowed by
the network policy (step 4).

An MCP server set up for the project in `.mcp.json` should read the key from
that variable, never contain it:

```json
{
  "mcpServers": {
    "example": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headers": { "Authorization": "Bearer ${EXAMPLE_API_KEY}" }
    }
  }
}
```

`.mcp.json` can then be committed safely; each person stores their own key
with `sbx secret`.

### One secret for all sandboxes, or one per project

| Scope | How | Use it for |
|---|---|---|
| global | `sbx secret set github` | a key you are happy for every sandbox, and so every project, to use |
| one sandbox | `sbx secret set github --sandbox my-project` | a key for one project, such as a fine-grained GitHub token limited to that project's repository |

Each project gets its own sandbox (step 6), so scoping a secret to the sandbox
scopes it to the project. Prefer per-sandbox secrets with the narrowest
permissions that work: anything running in a sandbox, including a plugin's
tools, can use the secrets that sandbox has.

### Seeing and removing secrets

```sh
sbx secret ls                               # all, with their scope; values are never shown
sbx secret ls --sandbox my-project          # one sandbox's
sbx secret rm github                        # the global one
sbx secret rm github --sandbox my-project   # one sandbox's
sbx secret import                           # offer keys found in your shell's environment (GH_TOKEN, OPENAI_API_KEY, …)
```

## 11. Changing plugins later

On the laptop, in the project folder:

```sh
cs-plugin outdated                 # pins with a newer release
cs-plugin upgrade cap-tools        # or: add NAME, remove NAME
git commit -am "Update plugin pins"
```

Then re-run step 7 to install the change in the sandbox, and restart Claude
(`sbx run --name my-project`). A co-worker who pulls the change does the same.

To use the plugins in another project, repeat steps 5–7 there: pins are per
project, and each project gets its own sandbox. Steps 1–4 are not repeated.

## 12. Cleaning up

```sh
sbx rm my-project          # deletes the sandbox and its plugin installs; the project folder stays
sbx secret ls              # then remove any secrets you scoped to it (step 10)
```

To take cs-plugin out of a project as well, delete `plugins.toml` and
`.claude/cs-plugin/`, and remove the `extraKnownMarketplaces` and
`enabledPlugins` entries from `.claude/settings.json`.

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Reference

- cs-plugin: https://github.com/ubyndr/cs-plugin (releases are tagged `pkg-cs-plugin--v<version>`)
- Docker Sandboxes: https://docs.docker.com/ai/sandboxes/
- sbx releases: https://github.com/docker/sbx-releases
