# Example 3: the `cap` CLI, without Claude

The `cap-tools` skills don't hold the code that talks to CAP. They call the
`cap` command-line tool from
[cap_skills](https://github.com/Cellular-Semantics/cap_skills)
(`packages/cap-client`), pinned to a tag. You can run that CLI yourself in the
sandbox. You don't need to install it, sign Claude in or install the plugin.
`uv` fetches the CLI from GitHub on first use and caches it.

Use it to:
- check that the tool and the network policy work, separately from Claude;
- get exact, repeatable numbers, or JSON/CSV files for scripts.

## Which version

Use the tag the pinned skills call, so you get the same code. Each skill's
`SKILL.md` has it; for `cap-tools` 0.4.0 it is `v0.4.0`:

```sh
sbx exec my-project bash -lc "grep -rho 'cap_skills@[^#]*' ~/.claude/plugins/cache/*/cap-tools/ | sort -u"
# cap_skills@v0.4.0
```

The sandbox has `uv` but not the `uvx` shortcut, so the commands below use
`uv tool run` instead of the `uvx` in cap_skills' README.

## One command from the laptop

```sh
sbx exec my-project bash -lc 'uv tool run --from "git+https://github.com/Cellular-Semantics/cap_skills@v0.4.0#subdirectory=packages/cap-client" cap datasets --consortium "Human Cell Atlas" --name lung --format text'
```

## A shell inside the sandbox

```sh
sbx exec -it my-project bash
```

Then, inside:

```sh
cap() { uv tool run --from "git+https://github.com/Cellular-Semantics/cap_skills@v0.4.0#subdirectory=packages/cap-client" cap "$@"; }

cap --version            # cap-client 0.4.0
cap --help               # datasets, consortia, feedback, labelsets, degs, expression, …
```

Define `cap` as a function, not a variable: `CAP="uv tool run …"; $CAP …`
does not split into words in zsh.

## Recorded output

Run on 2026-10-27 in the sandbox. These are the same questions as examples 1
and 2.

Lung datasets in the Human Cell Atlas:

```console
$ cap datasets --consortium "Human Cell Atlas" --name lung --format text
   1375       221,425  Human Cell Atlas     human lung organoid cell atlas
   1780       584,944  Human Cell Atlas     An integrated cell atlas of the human lung in health and disease (core)

2 datasets
```

SFTPC in the alveolar cell types of the HLCA core dataset (about 11 s):

```console
$ cap expression https://celltype.info/project/684/dataset/1780 \
    --genes SFTPC --labelset ann_finest_level \
    --cell-types AT2 "AT2 proliferating" AT0 AT1 --format text
Dataset 1780, labelset "ann_finest_level" (61 labels)
  embedding: umap (auto-detected)
  SFTPC          584944 cells  max=8.451
AT0	SFTPC	86.94	3.1613	1440
AT1	SFTPC	66.83	2.8946	7937
AT2	SFTPC	99.5	6.7271	61429
AT2 proliferating	SFTPC	96.82	5.6486	976
```

The text columns are: cell type, gene, % of cells expressing, mean among
expressing cells, number of cells. The default `--format json` names every
field, and also gives `mean_all`, the mean over all cells. That is the number
Claude reported in example 2 (AT2: 6.69), which is why the means there are a
little lower.

Other commands to try:

```sh
cap labelsets https://celltype.info/project/684/dataset/1780          # labelsets and labels
cap degs --help                                                       # marker genes per cell type

cd /Users/you/github/my-project              # the laptop's path to the project (not ~, which is /home/agent here)
cap expression https://celltype.info/project/684/dataset/1780 --genes SFTPC \
  --labelset ann_finest_level --csv sftpc.csv                         # also write CSV
```

The project folder is mounted at the same path inside the sandbox, so
`sftpc.csv` shows up in the project on the laptop.
