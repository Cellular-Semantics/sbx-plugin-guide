#!/usr/bin/env bash
# Switch the local sandbox network policy to "balanced", keeping custom rules.
#
#   scripts/sbx-policy-rebalance.sh [--dry-run]
#   scripts/sbx-policy-rebalance.sh --restore <backup.json>
#
# Saves every network rule you added (global and per-sandbox), runs
# `sbx policy reset` and `sbx policy init balanced`, then adds the saved rules
# back. Kit rules are recreated by sbx itself and are not touched.
# `sbx policy reset` stops running sandboxes; it asks before doing so.
# With --dry-run, prints the saved rules and the commands and changes nothing.
# With --restore, only adds back the custom rules from an earlier backup.
set -euo pipefail

dry_run=false
restore=false
if [[ "${1:-}" == "--dry-run" && $# -eq 1 ]]; then
  dry_run=true
elif [[ "${1:-}" == "--restore" && $# -eq 2 ]]; then
  restore=true
  backup=$2
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--dry-run] | --restore <backup.json>" >&2
  exit 2
fi

if ! $restore; then
  backup=~/sbx-policy-backup-$(date +%Y%m%d-%H%M%S).json
  sbx policy ls --source local --type network --json > "$backup"
  echo "Saved the current local network rules to $backup"
fi

# Turn each rule you added (not the init defaults) into an allow/deny command.
replay=$(python3 -I - "$backup" <<'EOF'
import json, shlex, sys

rules = json.load(open(sys.argv[1]))["rules"]
known = {"id", "name", "policy_id", "scope", "applies_to", "resource_type",
         "decision", "resources", "origin", "layer", "status", "editable",
         "provenance", "actions"}
for r in rules:
    if r.get("provenance", {}).get("created_via") == "default":
        continue
    extra = set(r) - known
    if extra:
        print(f"# skipped rule {r['id']}: has {sorted(extra)}, re-add it by hand",
              file=sys.stderr)
        continue
    cmd = ["sbx", "policy", r["decision"], "network"]
    target = r.get("applies_to", "all")
    if target.startswith("sandbox:"):
        cmd += ["--sandbox", target.removeprefix("sandbox:")]
    protocols = sorted({a.rsplit(":", 1)[-1] for a in r.get("actions", [])
                        if a.startswith("net:connect:")})
    if protocols and protocols != ["tcp"]:
        cmd += ["--protocol", ",".join(protocols)]
    cmd.append(",".join(r["resources"]))
    print(shlex.join(cmd))
EOF
)

echo
echo "Custom rules to add back after the reset:"
echo "${replay:-  (none)}"
echo

if $dry_run; then
  echo "Dry run: would run 'sbx policy reset', 'sbx policy init balanced', then the commands above."
  exit 0
fi

if ! $restore; then
  read -r -p "Reset the local policy and apply balanced? [y/N] " answer
  [[ "$answer" == [yY]* ]] || { echo "Aborted; nothing changed."; exit 1; }

  sbx policy reset
  # The restarted daemon may ask for a policy itself before init runs; if it
  # was set there, init reports "already initialized", which is fine.
  sbx policy init balanced || true
  if ! sbx policy ls --source local --created-via default --wide | grep -q default-code-and-containers; then
    echo "The global policy is not balanced; pick 'balanced' when asked, or run" >&2
    echo "'sbx policy reset' and 'sbx policy init balanced' by hand, then:" >&2
    echo "  $0 --restore $backup" >&2
    exit 1
  fi
fi

if [[ -n "$replay" ]]; then
  while IFS= read -r cmd; do
    echo "+ $cmd"
    eval "$cmd"
  done <<< "$replay"
fi

echo
sbx policy check network github.com:443
