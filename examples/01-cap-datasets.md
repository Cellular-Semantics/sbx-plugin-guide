# Example 1: find datasets with `cap-tools:cap-datasets`

Searches the [CAP](https://celltype.info) dataset catalogue. The prompt names
the skill explicitly with `/<plugin>:<skill>`.

## Run it

From the project folder on the laptop (sandbox created and plugins synced as
in [GUIDE.md](../GUIDE.md) steps 6–9):

```sh
./scripts/sbx-claude.sh my-project \
  "/cap-tools:cap-datasets list Human Cell Atlas datasets about the lung. Show at most 5 in a table."
```

which is the same as:

```sh
sbx exec -e PROJ="$PWD" my-project bash -lc 'cd "$PROJ" && claude -p --dangerously-skip-permissions "/cap-tools:cap-datasets list Human Cell Atlas datasets about the lung. Show at most 5 in a table."'
```

Or interactively: `sbx run --name my-project`, then type the same prompt.

## Recorded output

Run on 2026-10-27 (cap-tools 0.4.0, Claude Code 2.1.308 in the sandbox; 6
turns, about 18 s). Your wording will differ; the datasets should not.

> Only two of the Human Cell Atlas datasets on CAP are about the lung, so the table has two rows rather than five:
>
> | Dataset ID | Dataset | Project | Cells | URL |
> |---|---|---|---|---|
> | 1780 | An integrated cell atlas of the human lung in health and disease (core) | The integrated Human Lung Cell Atlas | 584,944 | https://celltype.info/project/684/dataset/1780 |
> | 1375 | human lung organoid cell atlas | Integrated human endoderm-derived organoids cell atlas (HEOCA) | 221,425 | https://celltype.info/project/604/dataset/1375 |
>
> I searched all 61 Human Cell Atlas datasets on CAP for lung-related words in the dataset and project names: lung, pulmonary, airway, respiratory, alveolar, bronchial and HLCA. Dataset 1780 is the core Human Lung Cell Atlas (HLCA). Dataset 1375 comes from lab-grown lung organoids, not tissue taken from people.
>
> A dataset that covers lung without using any of those words in its name won't appear here. For example, a multi-tissue atlas would be missed. If you name a lung cell type, I can also search by cell type to catch those.

## What this shows

- The skill came from the pinned plugin installed inside the sandbox, not from
  anything on the laptop.
- Its tool reached `celltype.info`, which works only because the network
  policy allows it ([GUIDE.md](../GUIDE.md) step 4). If it is blocked,
  `sbx policy log` shows the denied request.
