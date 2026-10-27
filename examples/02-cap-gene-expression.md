# Example 2: per-cell-type expression with `cap-tools:cap-gene-expression`

Asks which cell types express a gene most highly. Claude first has to find a
suitable lung dataset, then query expression in it, so this run takes more
steps than example 1.

## Run it

```sh
./scripts/sbx-claude.sh my-project \
  "/cap-tools:cap-gene-expression which cell types express SFTPC most highly in a CAP lung dataset? Keep the answer short."
```

## Recorded output

Run on 2026-10-27 (cap-tools 0.4.0, Claude Code 2.1.308 in the sandbox; 8
turns, about 50 s).

> AT2 cells express SFTPC most highly in the HLCA core dataset (`project/684/dataset/1780`, 584,944 cells, `ann_finest_level` labelset):
>
> | Cell type | Cells | % expressing | Mean (log1p) |
> |---|---|---|---|
> | **AT2** | 61,429 | 99.5 | 6.69 |
> | **AT2 proliferating** | 976 | 96.8 | 5.47 |
> | AT0 | 1,440 | 86.9 | 2.75 |
> | AT1 | 7,937 | 66.8 | 1.93 |
>
> The next-highest types (subpleural fibroblasts, pre-TB secretory, some macrophages) average about 1.2–1.4 but are 65–77% detected. That broad low-level signal is most likely ambient SFTPC RNA, a known artefact in lung data, not real expression. Ranked by mean, AT2 expresses several times more than any non-AT2 type.

## What this shows

- A skill can chain several tool calls in one prompt; with
  `--dangerously-skip-permissions` they run without approval, which is safe
  here because the sandbox is the boundary.
- SFTPC in AT2 cells is the expected answer, so this doubles as a quick check
  that the plugin and its network access work.

## Variations

- Drop the `/cap-tools:cap-gene-expression` prefix and ask in plain language;
  Claude picks the skill itself.
- Add `--json` to the script (see [the script](../scripts/sbx-claude.sh)) to
  get the answer, cost, duration and session ID as JSON.
