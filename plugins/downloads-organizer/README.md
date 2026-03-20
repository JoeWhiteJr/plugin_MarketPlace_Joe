# Downloads Organizer

A Claude Code plugin that scans the Windows Downloads folder, classifies files by project-specific rules, and sorts them into destination directories.

## Skills

### `/downloads-organizer:sort`

Full workflow: scan, report, AI-classify unknowns, confirm, and move files.

### `/downloads-organizer:sort --dry-run`

Scan and report only — no files are moved.

## Configuration

Edit `config.yaml` to add or modify rules. Three rule types:

**Simple rules** — match any pattern in the filename (case-insensitive):
```yaml
rules:
  - label: My Project
    patterns: [myproject, "my project"]
    dest: "{home}/MyProject/"
```

**Compound rules** — require a primary match plus a secondary keyword or extension:
```yaml
compound_rules:
  - label: MTC Turnover
    contains: MTC
    also_contains: [Turnover]
    or_extension: .sav
    dest: "{stats}/MTC Turnover/"
```

**IRB rules** — route IRB-related files by secondary keywords:
```yaml
irb_rules:
  - keywords: [dbit]
    dest: "{stats}/DBIT/"
  - fallback: "{stats}/Adv Research Projects/"
```

Placeholders `{stats}` and `{home}` resolve from `stats_dir` and `home_dir` at the top of the config.

## Cross-Filesystem Note

Moving files from NTFS (Windows Downloads) to ext4 (`/home/`) uses copy+delete instead of `mv` to avoid WSL permission issues. Same-filesystem moves (NTFS to NTFS, e.g., Downloads to OneDrive) use standard `shutil.move`.
