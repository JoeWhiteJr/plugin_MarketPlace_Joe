---
name: sort
description: "Scan Downloads folder, classify files by project rules, and sort them into destinations."
---

# Downloads Organizer — Sort

You are executing the `sort` skill — a structured workflow that scans the Windows Downloads folder, classifies files using project-specific rules, and optionally moves them to their destinations. Follow every phase in order.

---

## Phase 1 — Scan

Run the organizer in dry-run mode (no `--execute` flag):

```bash
python3 "$(dirname "$0")/../../organizer.py"
```

If the command fails or returns an error key in the JSON, stop and report the issue to the user.

Parse the JSON output and store it for the remaining phases.

---

## Phase 2 — Report

Present a formatted summary to the user:

1. **Files to move** — grouped by label/destination. Show count and total size per group.
2. **Flagged installers** — list each with size. Note these won't be moved automatically.
3. **Flagged large videos** — list each with size.
4. **Duplicate groups** — show each group with file names and sizes.
5. **Unclassified files** — count and list them.
6. **Grand totals** — scanned, to move, skipped, flagged, unclassified.

Use a clean table or grouped list format. Keep it scannable.

---

## Phase 3 — AI Classification

For each file in the `unclassified` list:

1. Examine the filename, extension, and size.
2. Consider known project directories:
   - Stats projects: Spirituality, DBIT, MK Labs, Growth Summit, OOA, iHub Investors, Finance, MGMT courses, etc.
   - Home projects: ~/Special-Sprinkle-Sauce, ~/Meridian, ~/Weekender, ~/Utah_Commuting, ~/LevelUp
3. Look for keyword matches, course codes, project names, or recognizable patterns in the filename.
4. Present suggestions as a table:

| File | Suggested Destination | Confidence | Reasoning |
|------|----------------------|------------|-----------|
| mystery.docx | /mnt/c/.../Stats/MGMT 2340/ | High | Contains "MGMT" in name |

5. If no reasonable guess can be made, mark as "No suggestion" with a note.

---

## Phase 4 — Confirmation Gate

**If `$ARGUMENTS` contains `--dry-run`:** Stop here. Tell the user:
> Dry run complete. No files were moved. Run `/downloads-organizer:sort` without `--dry-run` to execute.

**Otherwise:** Ask the user to confirm:
1. Show the total count of files that will be moved.
2. Ask if they want to approve/reject any AI suggestions for unclassified files.
3. Wait for explicit confirmation before proceeding to Phase 5.

---

## Phase 5 — Execute

1. If the user approved AI suggestions, write them to a temporary JSON file (`/tmp/ai_moves.json`) in the format:
   ```json
   [{"file": "name.ext", "file_path": "/full/path", "size": "1.2MB", "dest": "/dest/path/"}]
   ```

2. Run the organizer with `--execute` (and `--move-list` if AI suggestions were approved):
   ```bash
   python3 "$(dirname "$0")/../../organizer.py" --execute --move-list /tmp/ai_moves.json
   ```
   Or without `--move-list` if no AI suggestions:
   ```bash
   python3 "$(dirname "$0")/../../organizer.py" --execute
   ```

3. Parse the results and report:
   - Success count
   - Any failures with error messages
   - Remaining items in Downloads (run `ls /mnt/c/Users/josep/Downloads | wc -l`)

4. Clean up the temp file if created: `rm -f /tmp/ai_moves.json`

---

## Error Handling

- **Downloads dir missing:** Stop with a clear message. The path may need updating in `config.yaml`.
- **Empty Downloads:** Report "Nothing to organize" and stop.
- **Config missing:** Stop and tell the user where to find/create `config.yaml`.
- **Individual file failures:** Log the error and continue with remaining files. Report all failures at the end.
- **Permission denied on cross-fs move:** The organizer handles this (copy+delete for NTFS->ext4), but if it still fails, report the specific file and suggest manual intervention.
