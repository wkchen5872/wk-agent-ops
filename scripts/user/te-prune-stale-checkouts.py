#!/usr/bin/env python3
"""Drop TokenEconomizer state that points at checkouts which no longer exist.

TokenEconomizer remembers every checkout it has seen and writes its settings back to them
(`.codex/config.toml`, `.claude/settings.local.json`), recreating directories of worktrees that
were already removed, such as handoff loop worktrees after `handoff-cleanup`. This script:

- removes checkouts that no longer exist from `index.json`;
- removes applied-settings paths whose checkout is gone from each `untool_applied.json`;
- moves a pending deny list (`auto_pending.root` in `untool.json`) whose checkout is gone to a
  checkout of the same repository that still exists, or drops it when none is left.

Session history and learned facts are not touched.

Usage: python3 -I scripts/user/te-prune-stale-checkouts.py [--dry-run]
State directory: $TOKENECONOMIZER_HOME, default ~/.tokeneconomizer. Back it up first if unsure.
"""
import glob
import json
import os
import sys

TE = os.environ.get("TOKENECONOMIZER_HOME") or os.path.expanduser("~/.tokeneconomizer")
DRY = "--dry-run" in sys.argv


def load(path):
    with open(path) as f:
        return json.load(f)


def save(path, data):
    if DRY:
        return
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)


def checkout_root(path):
    # <root>/.codex/config.toml or <root>/.claude/settings.local.json -> <root>
    parent = os.path.dirname(path)
    return os.path.dirname(parent) if os.path.basename(parent).startswith(".") else parent


def main():
    idx_path = os.path.join(TE, "index.json")
    idx = load(idx_path)
    checkouts = idx.get("checkouts", {})
    gone = [p for p in checkouts if not os.path.exists(p)]
    for p in gone:
        del checkouts[p]
    save(idx_path, idx)
    print(f"index.json: removed {len(gone)} checkouts")

    alive = {}
    for p, v in checkouts.items():
        alive.setdefault(v.get("key"), []).append(p)

    for f in sorted(glob.glob(os.path.join(TE, "repos", "*", "*", "untool_applied.json"))):
        data = load(f)
        by_path = data.get("by_path", {})
        drop = [p for p in by_path if not os.path.exists(checkout_root(p))]
        for p in drop:
            del by_path[p]
        if drop:
            save(f, data)
            print(f"{os.path.relpath(f, TE)}: removed {len(drop)} paths")

    for f in sorted(glob.glob(os.path.join(TE, "repos", "*", "*", "untool.json"))):
        data = load(f)
        pending = data.get("auto_pending")
        root = pending.get("root") if isinstance(pending, dict) else None
        if not root or os.path.exists(root):
            continue
        key = os.path.relpath(f, os.path.join(TE, "repos")).split(os.sep)[0]
        others = sorted(alive.get(key, []))
        if others:
            pending["root"] = others[0]
            print(f"{os.path.relpath(f, TE)}: pending root -> {others[0]}")
        else:
            del data["auto_pending"]
            print(f"{os.path.relpath(f, TE)}: pending removed (no checkout left)")
        save(f, data)


if __name__ == "__main__":
    main()
