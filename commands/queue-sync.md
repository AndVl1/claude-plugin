---
description: Pull GitHub issues into local task queue cache (.work-state/queue.json)
argument-hint: [--label LABEL] [--repo OWNER/REPO] [--limit N]
---

# Queue Sync

Pulls GitHub issues matching a filter into a local cache used by `/team-next`.
Does **not** execute anything — only refreshes the queue file.

## Arguments

Parse `$ARGUMENTS` for flags (all optional):

- `--label <name>` — filter by label. Default: `autonomous`
- `--repo <owner/name>` — explicit repo. Default: current repo (from `gh repo view`)
- `--limit <n>` — max issues to pull. Default: `50`
- `--state <open|all>` — issue state. Default: `open`

If user passed nothing, use defaults.

## Steps

### 1. Resolve repo

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

Fail fast if `gh` not authenticated (`gh auth status`).

### 2. Fetch issues

```bash
gh issue list \
  --repo "$REPO" \
  --label "$LABEL" \
  --state "$STATE" \
  --limit "$LIMIT" \
  --json number,title,body,url,labels,assignees,updatedAt
```

Filter out issues with blocking labels: `blocked`, `needs-human`, `wip`, `in-progress`.

### 3. Merge with existing cache

Read existing `.work-state/queue.json` if present. For each fetched issue:

- **New issue** (not in cache) → append with `status: "pending"`
- **Existing issue** in cache with status `done` or `in-progress` → leave as-is (don't re-queue)
- **Existing issue** with status `pending` → update title/body/labels from fresh data
- **Issue removed from GitHub filter** → mark as `stale: true` (don't delete; user decides)

### 4. Write cache

Format `.work-state/queue.json`:

```json
{
  "repo": "owner/name",
  "label": "autonomous",
  "synced_at": "2026-04-17T12:00:00Z",
  "tasks": [
    {
      "id": 42,
      "title": "Add X",
      "body": "...",
      "url": "https://github.com/owner/name/issues/42",
      "labels": ["autonomous", "backend"],
      "status": "pending",
      "report_path": null,
      "pr_url": null,
      "updated_at": "2026-04-17T10:00:00Z"
    }
  ]
}
```

Pretty-print (2-space indent) for git-friendliness.

### 5. Report

Short summary to user:

```
Queue synced: 5 pending, 2 in-progress, 12 done (repo: owner/name, label: autonomous)
New this sync: #42, #51
```

## Notes

- This command is **idempotent** and **read-only w.r.t. GitHub**. Safe to run anytime.
- `.work-state/queue.json` is gitignored (per existing `.gitignore` rules for `.work-state/`).
- Do NOT call `/team` from here. Queue sync is separate from execution.

---

**Arguments**: $ARGUMENTS

Start syncing.
