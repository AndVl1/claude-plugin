---
name: publish-gist-report
description: "Publish E2E/QA test reports (markdown + screenshots) as secret GitHub Gists. Uses two-gist pattern to work around GitHub rendering limits. Trigger when: report needs to be shared via gist, E2E test run completed and report must be published, user asks to \"upload report\", \"publish to gist\", \"share test results\", or after manual-qa produces a report with screenshots."
---

# Publish Gist Report

Publish a test report (markdown + PNGs) as a pair of secret GitHub Gists.

## Why two gists

- `gh gist create` rejects binary files
- Data URIs don't render in gist markdown
- A single gist with many PNGs stops rendering markdown entirely (blank page)

Solution: **assets gist** (PNGs via git) + **report gist** (markdown with raw URLs).

## Procedure

### 1. Create assets gist (if report has screenshots)

```bash
# Seed with a placeholder so the gist exists
echo "Assets for report" > /tmp/gist-assets-readme.md
ASSETS_URL=$(gh gist create /tmp/gist-assets-readme.md --desc "Assets: <report-title>" | tail -1)
ASSETS_ID=$(echo "$ASSETS_URL" | sed 's|.*/||')
```

### 2. Push PNGs into assets gist via git

```bash
WORK=$(mktemp -d)
git clone "https://gist.github.com/$ASSETS_ID.git" "$WORK"
cp <screenshot-dir>/*.png "$WORK/"
cd "$WORK" && git add *.png && git commit -m "add screenshots"
git remote set-url origin "https://$(gh auth token)@gist.github.com/$ASSETS_ID.git"
git push origin HEAD
cd - && rm -rf "$WORK"
```

### 3. Rewrite image paths in report markdown

Replace every local image reference with a raw gist URL:

```
![alt](./foo.png)
->
![alt](https://gist.githubusercontent.com/<username>/<assets_gist_id>/raw/foo.png)
```

The `/raw/<filename>` URL (no commit hash) always resolves to HEAD.

Get `<username>` via `gh api user -q .login`.

### 4. Create report gist

```bash
REPORT_URL=$(gh gist create report.md --desc "<report-title>" | tail -1)
```

### 5. Verify

```bash
# Check at least one raw image URL returns 200
curl -sI "https://gist.githubusercontent.com/<username>/$ASSETS_ID/raw/<any>.png" | head -1
```

### 6. Finalize

- Return both URLs to the user (report gist is the primary link).
- Append report gist URL to the bottom of the local report file for traceability.

## Constraints

- **Secret gists only.** Reports may contain internal URLs, usernames, tokens in screenshots.
- **No screenshots without the two-gist split.** If report has zero images, a single gist is fine.
- **Verify before reporting success.** At least one `curl -sI` on a raw URL must return HTTP 200.
