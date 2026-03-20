#!/usr/bin/env python3
"""Scan Downloads folder, classify files by YAML rules, output JSON report or execute moves."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path
from typing import NamedTuple

import yaml

# ── Classification buckets ───────────────────────────────────────────────────
SKIP = "SKIP"
FLAG_INSTALLER = "FLAG_INSTALLER"
FLAG_LARGE_VIDEO = "FLAG_LARGE_VIDEO"
UNCLASSIFIED = "UNCLASSIFIED"

DUP_RE = re.compile(r" \(\d+\)")


class FileInfo(NamedTuple):
    path: Path
    name: str
    ext: str       # lowercase, includes dot
    size: int      # bytes


class Classification(NamedTuple):
    file: FileInfo
    bucket: str       # destination path, or SKIP/FLAG_*/UNCLASSIFIED
    label: str        # human-readable rule name


def human_size(nbytes: int) -> str:
    """Return human-readable file size."""
    for unit in ("B", "KB", "MB", "GB"):
        if nbytes < 1024:
            return f"{nbytes:.1f}{unit}"
        nbytes /= 1024
    return f"{nbytes:.1f}TB"


def load_config(path: Path) -> dict:
    """Read YAML config and resolve {stats}/{home} placeholders in all dest fields."""
    with open(path, encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh)

    stats = cfg["stats_dir"]
    home = cfg["home_dir"]

    def resolve(s: str) -> str:
        return s.replace("{stats}", stats).replace("{home}", home)

    for rule in cfg.get("rules", []):
        rule["dest"] = resolve(rule["dest"])

    for rule in cfg.get("compound_rules", []):
        rule["dest"] = resolve(rule["dest"])

    for rule in cfg.get("irb_rules", []):
        if "dest" in rule:
            rule["dest"] = resolve(rule["dest"])
        if "fallback" in rule:
            rule["fallback"] = resolve(rule["fallback"])

    cfg["stats_script_dest"] = resolve(f"{{stats}}/{cfg.get('stats_script_dest', 'Adv Research Projects/')}")
    cfg["skip_extensions"] = set(cfg.get("skip_extensions", []))
    cfg["flag_installer_extensions"] = set(cfg.get("flag_installer_extensions", []))
    cfg["stats_script_extensions"] = set(cfg.get("stats_script_extensions", []))

    return cfg


def scan_downloads(downloads_dir: Path) -> list[FileInfo]:
    """Collect all files and directories in Downloads."""
    if not downloads_dir.exists():
        return []
    items: list[FileInfo] = []
    for p in sorted(downloads_dir.iterdir()):
        try:
            size = (
                sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
                if p.is_dir()
                else p.stat().st_size
            )
        except OSError:
            size = 0
        items.append(FileInfo(path=p, name=p.name, ext=p.suffix.lower(), size=size))
    return items


def classify(f: FileInfo, cfg: dict) -> Classification:
    """Apply rules in priority order. First match wins."""
    name = f.name
    name_lower = name.lower()
    ext = f.ext

    # Office temp files
    if name.startswith("~$") or name.startswith("~WRL"):
        return Classification(f, SKIP, "Office temp")

    # System files
    if name_lower in ("desktop.ini", ".zone.identifier"):
        return Classification(f, SKIP, "System file")

    # Skip extensions (images, audio, video clips, tmp)
    if ext in cfg["skip_extensions"]:
        return Classification(f, SKIP, f"Skip ext {ext}")

    # Large video
    threshold = cfg.get("large_video_threshold_mb", 100) * 1024 * 1024
    if ext in (".mp4", ".mov") and f.size > threshold:
        return Classification(f, FLAG_LARGE_VIDEO, "Large video")

    # Installers
    if ext in cfg["flag_installer_extensions"]:
        return Classification(f, FLAG_INSTALLER, "Installer/ISO")

    # Compound rules (e.g. MTC Turnover)
    for rule in cfg.get("compound_rules", []):
        contains = rule["contains"]
        also = rule.get("also_contains", [])
        or_ext = rule.get("or_extension", "")
        if contains in name:
            if any(kw in name for kw in also) or (or_ext and ext == or_ext):
                return Classification(f, rule["dest"], rule["label"])
            # If contains matches but no secondary condition and also_contains is empty
            if not also and not or_ext:
                return Classification(f, rule["dest"], rule["label"])

    # General pattern rules
    for rule in cfg.get("rules", []):
        for pat in rule["patterns"]:
            if pat.lower() in name_lower:
                return Classification(f, rule["dest"], rule["label"])

    # IRB routing
    if "IRB" in name.upper():
        irb_lower = name_lower
        for irb_rule in cfg.get("irb_rules", []):
            if "keywords" in irb_rule:
                if any(kw in irb_lower for kw in irb_rule["keywords"]):
                    return Classification(f, irb_rule["dest"], f"IRB -> {irb_rule['dest'].split('/')[-2]}")
            elif "fallback" in irb_rule:
                return Classification(f, irb_rule["fallback"], "IRB (unmatched)")

    # Stats script extensions fallback
    if ext in cfg["stats_script_extensions"]:
        return Classification(f, cfg["stats_script_dest"], "Stats script")

    return Classification(f, UNCLASSIFIED, "Unclassified")


def detect_duplicates(files: list[FileInfo]) -> dict[str, list[FileInfo]]:
    """Group files that look like duplicates: foo.ext, foo (1).ext, foo (2).ext."""
    groups: dict[str, list[FileInfo]] = {}
    for f in files:
        stem = f.path.stem
        base = DUP_RE.sub("", stem)
        key = f"{base}{f.ext}".lower()
        groups.setdefault(key, []).append(f)
    return {k: v for k, v in groups.items() if len(v) > 1}


def execute_moves(to_move: list[dict]) -> list[dict]:
    """Move files to their destinations. Returns results list."""
    results: list[dict] = []
    for item in to_move:
        src = Path(item["file_path"])
        dest_dir = Path(item["dest"])
        try:
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / src.name
            # Cross-filesystem: copy then remove (WSL NTFS->ext4 quirk)
            if str(dest_dir).startswith("/home/"):
                shutil.copy2(str(src), str(dest_path))
                if src.is_dir():
                    shutil.rmtree(str(src))
                else:
                    src.unlink()
            else:
                shutil.move(str(src), str(dest_path))
            results.append({"file": src.name, "dest": str(dest_dir), "status": "ok"})
        except Exception as e:
            results.append({"file": src.name, "dest": str(dest_dir), "status": "error", "error": str(e)})
    return results


def build_output(classified: list[Classification], dupes: dict[str, list[FileInfo]]) -> dict:
    """Build the JSON output structure."""
    to_move: list[dict] = []
    skipped: list[dict] = []
    flagged_installers: list[dict] = []
    flagged_large_videos: list[dict] = []
    unclassified: list[dict] = []

    for c in classified:
        entry = {"file": c.file.name, "file_path": str(c.file.path), "size": human_size(c.file.size)}
        if c.bucket == SKIP:
            skipped.append({"file": c.file.name, "reason": c.label})
        elif c.bucket == FLAG_INSTALLER:
            flagged_installers.append(entry)
        elif c.bucket == FLAG_LARGE_VIDEO:
            flagged_large_videos.append(entry)
        elif c.bucket == UNCLASSIFIED:
            unclassified.append(entry)
        else:
            entry["label"] = c.label
            entry["dest"] = c.bucket
            to_move.append(entry)

    duplicate_groups: list[dict] = []
    for key, group in sorted(dupes.items()):
        duplicate_groups.append({
            "group": key,
            "files": [{"name": f.name, "size": human_size(f.size)} for f in sorted(group, key=lambda f: f.name)],
        })

    return {
        "scanned": len(classified),
        "to_move": to_move,
        "skipped": skipped,
        "flagged_installers": flagged_installers,
        "flagged_large_videos": flagged_large_videos,
        "duplicates": duplicate_groups,
        "unclassified": unclassified,
        "results": [],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Downloads organizer — classify and sort files")
    parser.add_argument("--config", type=Path, default=Path(__file__).parent / "config.yaml",
                        help="Path to config.yaml (default: alongside this script)")
    parser.add_argument("--execute", action="store_true",
                        help="Actually move the classified files")
    parser.add_argument("--move-list", type=Path, default=None,
                        help="JSON file with additional moves (for AI-suggested classifications)")
    args = parser.parse_args()

    # Load config
    if not args.config.exists():
        json.dump({"error": f"Config not found: {args.config}"}, sys.stdout, indent=2)
        sys.exit(1)

    cfg = load_config(args.config)
    downloads_dir = Path(cfg["downloads_dir"])

    if not downloads_dir.exists():
        json.dump({"error": f"Downloads directory not found: {downloads_dir}"}, sys.stdout, indent=2)
        sys.exit(1)

    # Scan and classify
    files = scan_downloads(downloads_dir)
    if not files:
        json.dump({"scanned": 0, "to_move": [], "skipped": [], "flagged_installers": [],
                    "flagged_large_videos": [], "duplicates": [], "unclassified": [], "results": []},
                   sys.stdout, indent=2)
        sys.exit(0)

    classified = [classify(f, cfg) for f in files]

    # Detect duplicates among non-skipped files
    non_skipped = [c.file for c in classified if c.bucket != SKIP]
    dupes = detect_duplicates(non_skipped)

    # Build output
    output = build_output(classified, dupes)

    # Execute moves if requested
    if args.execute:
        all_moves = list(output["to_move"])

        # Merge in AI-suggested moves from --move-list
        if args.move_list and args.move_list.exists():
            with open(args.move_list, encoding="utf-8") as fh:
                extra_moves = json.load(fh)
            all_moves.extend(extra_moves)

        output["results"] = execute_moves(all_moves)

    json.dump(output, sys.stdout, indent=2)
    print()  # trailing newline


if __name__ == "__main__":
    main()
