# Examples

Prompts run against this repo's pinned plugins inside a Docker Sandbox, with
the output recorded. They assume you have done [GUIDE.md](../GUIDE.md) steps
1–9: sandbox created, plugins synced, Claude signed in.

| Example | Skill | What it does |
|---|---|---|
| [01-cap-datasets.md](01-cap-datasets.md) | `cap-tools:cap-datasets` | find lung datasets in the CAP catalogue |
| [02-cap-gene-expression.md](02-cap-gene-expression.md) | `cap-tools:cap-gene-expression` | which cell types express SFTPC |

All of them use [`scripts/sbx-claude.sh`](../scripts/sbx-claude.sh), a thin
wrapper over the one-shot `sbx exec … claude -p` command explained in
[GUIDE.md § 9](../GUIDE.md#one-shot-from-the-laptops-terminal).

Answers come from a language model calling live services, so the wording and
some details change between runs.
