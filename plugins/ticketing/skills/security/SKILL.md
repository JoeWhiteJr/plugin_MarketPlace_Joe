---
name: security
description: Run security scanners (Gitleaks, Bandit, npm audit, eslint-plugin-security) against the repo, map findings to OWASP Top 10 where applicable, and optionally create tickets for findings.
disable-model-invocation: true
---

# Security Audit

You are executing the `security` skill — running a suite of security scanners across the repo, summarizing the findings, mapping them to the OWASP Top 10 where applicable, and optionally turning HIGH/CRITICAL findings into tickets.

**This skill is diagnostic only.** It NEVER auto-fixes, NEVER modifies dependency files (`package.json`, `pyproject.toml`, lockfiles), and NEVER pushes anything. All remediation is left to the user.

`$ARGUMENTS` is optional. Supported forms:
- empty (default) → run all applicable scanners, report to chat
- `--tickets` → run all applicable scanners AND auto-create tickets for every HIGH or CRITICAL finding
- `--quick` → skip slower scanners (npm audit, eslint-security); run Gitleaks + Bandit only
- `gitleaks` / `bandit` / `npm-audit` / `eslint-security` → run only that specific scanner

If `$ARGUMENTS` contains an unrecognized token, stop and report:
> Usage: `/ticketing:security [--tickets | --quick | gitleaks | bandit | npm-audit | eslint-security]`

---

## Phase 1 — Locate Repo and Parse Mode

1. Run `git rev-parse --show-toplevel` to get `ROOT`. If it fails, fall back to the current working directory and warn.
2. Determine the repo name: basename of `ROOT`.
3. Parse `$ARGUMENTS` into these flags:
   - `TICKETS_MODE` (bool) — true if `--tickets` present
   - `QUICK_MODE` (bool) — true if `--quick` present
   - `ONLY_SCANNER` (string|null) — set to `gitleaks`, `bandit`, `npm-audit`, or `eslint-security` if that single scanner was named
4. Compute today's ISO date (`YYYY-MM-DD`).
5. Initialize empty `FINDINGS[]` collector. Each finding has:
   `{ scanner, rule, severity (CRITICAL|HIGH|MEDIUM|LOW|INFO), file, line, description, owasp (string or null), raw }`
6. Initialize `TOOL_STATUS[]`: one entry per scanner with `{ name, version, status (ran|skipped|not-installed|failed), note }`.

---

## Phase 2 — Detect Applicable Scanners

Decide which scanners to attempt based on repo contents and `$ARGUMENTS`:

1. **Gitleaks:** always applicable. Run unless `ONLY_SCANNER` is set to something else.
2. **Bandit:** applicable if ANY of the following is true:
   - `<ROOT>/backend/` exists
   - `<ROOT>/pyproject.toml` exists
   - Glob `<ROOT>/**/*.py` returns at least one file (excluding `node_modules`, `.venv`, `venv`, `.git`)
   Pick the Python target directory: `backend/` if present, else `<ROOT>`.
3. **npm audit:** applicable if any `package.json` exists (exclude ones inside `node_modules/`). Collect all matching directories as `NPM_DIRS[]`. Skip if `QUICK_MODE` is true.
4. **eslint-plugin-security:** applicable if any `package.json` with an ESLint config (`.eslintrc*`, or `eslintConfig` key in package.json) exists. Skip if `QUICK_MODE` is true.

If `ONLY_SCANNER` is set, only run that one scanner (skip all others entirely — don't even add them to `TOOL_STATUS`).

---

## Phase 3 — Run Gitleaks

Skip if not applicable.

1. Check install: `which gitleaks`. If it returns nothing:
   - Add to `TOOL_STATUS`: `{ name: "Gitleaks", status: "not-installed", note: "Download binary from github.com/gitleaks/gitleaks/releases or `brew install gitleaks` on macOS" }`
   - Skip to next scanner.
2. Get version: `gitleaks version 2>/dev/null | head -1`.
3. Run: `gitleaks detect --source <ROOT> --no-git --report-format json --report-path /tmp/gitleaks-report.json` (the `--no-git` flag scans the current worktree only, not git history, which is what we want).
4. Gitleaks exits **non-zero when leaks are found** — that's expected, not a failure. Only treat it as failed if the report file doesn't exist afterward.
5. Parse `/tmp/gitleaks-report.json` (it's a JSON array). For each entry:
   - `file` = `.File`
   - `line` = `.StartLine`
   - `rule` = `.RuleID`
   - `description` = `.Description`
   - `severity` = `HIGH` (Gitleaks findings are all treated as HIGH — secrets in code are never low-severity)
   - `owasp` = `A02` (Cryptographic Failures) — though A07 is also relevant, use A02 as primary
   - Append to `FINDINGS[]`.
6. Add to `TOOL_STATUS`: `{ name: "Gitleaks", version: <v>, status: "ran", note: "report: /tmp/gitleaks-report.json" }`.
7. If the gitleaks command itself crashes (not just a non-zero exit), catch the error and add status `failed` with the stderr message. Continue with other scanners.

---

## Phase 4 — Run Bandit

Skip if not applicable.

1. Check install: `which bandit`. If not found:
   - Add to `TOOL_STATUS`: `{ name: "Bandit", status: "not-installed", note: "pip install bandit" }`
   - Skip.
2. Get version: `bandit --version 2>/dev/null | head -1`.
3. Run: `bandit -r <python-target> -f json -o /tmp/bandit-report.json -ll` (the `-ll` flag means medium severity and above).
4. Bandit exits non-zero if findings exist — also expected. Only fail if the report file doesn't exist.
5. Parse `/tmp/bandit-report.json`. For each entry in `.results[]`:
   - `file` = `.filename`
   - `line` = `.line_number`
   - `rule` = `.test_id` (e.g., `B608`)
   - `description` = `.issue_text`
   - `severity` = map from Bandit's `.issue_severity`:
     - `HIGH` → HIGH
     - `MEDIUM` → MEDIUM
     - `LOW` → LOW
     (Bandit doesn't emit CRITICAL.)
   - `owasp` = look up in the mapping table below. If unknown, set to `null`.
   - Append to `FINDINGS[]`.
6. **Bandit → OWASP mapping table** (partial; `null` for anything not listed):
   | Bandit rule | OWASP |
   |-------------|-------|
   | B101 (assert_used) | A04 |
   | B102 (exec_used) | A03 |
   | B103 (set_bad_file_permissions) | A05 |
   | B104 (hardcoded_bind_all_interfaces) | A05 |
   | B105/B106/B107 (hardcoded_password*) | A07 |
   | B108 (hardcoded_tmp_directory) | A05 |
   | B201 (flask_debug_true) | A05 |
   | B301 (pickle) | A08 |
   | B302 (marshal) | A08 |
   | B303 (md5) | A02 |
   | B304/B305 (weak ciphers) | A02 |
   | B306 (mktemp_q) | A01 |
   | B307 (eval) | A03 |
   | B310 (urllib_urlopen) | A10 |
   | B311 (random) | A02 |
   | B321 (ftplib) | A02 |
   | B324 (hashlib insecure) | A02 |
   | B501 (request_with_no_cert_validation) | A02 |
   | B502/B503/B504 (ssl weak versions) | A02 |
   | B506 (yaml_load) | A08 |
   | B601 (paramiko_calls) | A03 |
   | B602 (subprocess_popen_with_shell_equals_true) | A03 |
   | B603/B604/B605/B606/B607 (subprocess/shell) | A03 |
   | B608 (sql injection) | A03 |
   | B609 (linux_commands_wildcard_injection) | A03 |
   | B610 (django_extra_used) | A03 |
   | B611 (django_rawsql_used) | A03 |
   | B701 (jinja2_autoescape_false) | A03 |
   | B702 (use_of_mako_templates) | A03 |
   | B703 (django_mark_safe) | A03 |
7. Add to `TOOL_STATUS`: `{ name: "Bandit", version: <v>, status: "ran", note: "report: /tmp/bandit-report.json" }`.
8. If bandit crashes, catch and mark `failed`. Continue.

---

## Phase 5 — Run npm audit

Skip if not applicable, or if `QUICK_MODE`.

1. Check install: `which npm`. If not found:
   - Add to `TOOL_STATUS`: `{ name: "npm audit", status: "not-installed", note: "Install Node.js" }`.
   - Skip.
2. For each directory `D` in `NPM_DIRS[]`:
   1. Run: `cd "<D>" && npm audit --json > /tmp/npm-audit-<basename(D)>.json 2>/dev/null`. Capture stdout to the file. `npm audit` also exits non-zero when vulns found — expected.
   2. If the file is empty or not valid JSON, skip this dir and note the failure.
   3. Parse the JSON. The shape is:
      ```
      { "vulnerabilities": {
          "<package-name>": {
            "severity": "info|low|moderate|high|critical",
            "via": [ ... ],
            "effects": [ ... ],
            "range": "...",
            ...
          }, ...
        }, "metadata": { ... }
      }
      ```
   4. For each entry in `.vulnerabilities`:
      - `file` = `"<D>/package.json"`
      - `line` = null
      - `rule` = package name
      - `description` = summary of `.via[]` entries (titles, joined with `; `)
      - `severity` = map: `critical → CRITICAL`, `high → HIGH`, `moderate → MEDIUM`, `low → LOW`, `info → INFO`
      - `owasp` = `A06` (Vulnerable and Outdated Components)
      - Append to `FINDINGS[]`.
3. Add to `TOOL_STATUS`: `{ name: "npm audit", version: <npm --version>, status: "ran", note: "scanned N directories" }`.
4. If `QUICK_MODE` skipped this, add `{ name: "npm audit", status: "skipped", note: "--quick mode" }`.
5. If npm itself crashes in a dir, log and continue with the next dir.

---

## Phase 6 — Run eslint-plugin-security

Skip if not applicable, or if `QUICK_MODE`.

1. For each applicable `package.json` dir `D`:
   1. Check if `eslint-plugin-security` is in `devDependencies` or `dependencies` of that `package.json`. If not:
      - Add to `TOOL_STATUS`: `{ name: "eslint-plugin-security (<D>)", status: "not-installed", note: "To enable: cd <D> && npm install --save-dev eslint-plugin-security, then add 'plugin:security/recommended' to .eslintrc" }`.
      - Skip this dir.
   2. Check that ESLint is invocable: `cd "<D>" && npx --no-install eslint --version`. If that fails, mark status `not-installed` with hint `"ESLint not available in <D>"` and skip.
   3. Determine the source dir: `src/` if it exists under `D`, else `D`.
   4. Run: `cd "<D>" && npx --no-install eslint --ext .js,.ts,.tsx --format json <src-dir> > /tmp/eslint-security-<basename(D)>.json 2>/dev/null`. ESLint also exits non-zero when issues exist.
   5. Parse the JSON (array of `{ filePath, messages: [...] }`).
   6. For each message where `.ruleId` starts with `security/`:
      - `file` = `.filePath` (relative to ROOT)
      - `line` = `.line`
      - `rule` = `.ruleId`
      - `description` = `.message`
      - `severity`: map ESLint severity `2` → MEDIUM (most security rules are warnings about plausible patterns, not certain bugs). If the rule name contains `eval`, `child-process`, `non-literal-require`, or `buffer-noassert`, bump to HIGH.
      - `owasp` mapping (partial):
        | Rule | OWASP |
        |------|-------|
        | security/detect-object-injection | A03 |
        | security/detect-non-literal-regexp | A03 |
        | security/detect-unsafe-regex | A05 (DoS) |
        | security/detect-buffer-noassert | A05 |
        | security/detect-child-process | A03 |
        | security/detect-disable-mustache-escape | A03 |
        | security/detect-eval-with-expression | A03 |
        | security/detect-no-csrf-before-method-override | A01 |
        | security/detect-non-literal-fs-filename | A01 |
        | security/detect-non-literal-require | A08 |
        | security/detect-possible-timing-attacks | A02 |
        | security/detect-pseudoRandomBytes | A02 |
      - Append to `FINDINGS[]`.
2. Add one `TOOL_STATUS` entry per dir scanned, or an overall `skipped` entry if `QUICK_MODE`.

---

## Phase 7 — Aggregate and Generate Report

1. Count findings by severity: `CRITICAL_N`, `HIGH_N`, `MEDIUM_N`, `LOW_N`, `INFO_N`.
2. Count findings by OWASP bucket (A01 through A10; group unmapped as `null`).
3. Sort `FINDINGS[]` by severity (CRITICAL > HIGH > MEDIUM > LOW > INFO), then by scanner, then by file.
4. Write the following report to chat:

```
# Security Audit — <REPO_NAME> — <ISO date>

## Tools used
- <status-emoji> Gitleaks (<version or "—">) <if skipped/failed: reason>
- <status-emoji> Bandit (<version or "—">) <if skipped/failed: reason>
- <status-emoji> npm audit (<version or "—">) <if skipped/failed: reason>
- <status-emoji> eslint-plugin-security (<version or "—">) <if skipped/failed: reason>
```

Status emoji rules:
- `ran` → ✅
- `skipped` → ⚠️
- `not-installed` → ❌
- `failed` → 💥

Then:

```
## Summary
| Severity | Findings |
|----------|----------|
| CRITICAL | {CRITICAL_N} |
| HIGH | {HIGH_N} |
| MEDIUM | {MEDIUM_N} |
| LOW | {LOW_N} |
| INFO | {INFO_N} |

## Findings by OWASP Top 10
| OWASP | Name | Count |
|-------|------|-------|
| A01 | Broken Access Control | {n} |
| A02 | Cryptographic Failures | {n} |
| A03 | Injection | {n} |
| A04 | Insecure Design | {n} |
| A05 | Security Misconfiguration | {n} |
| A06 | Vulnerable and Outdated Components | {n} |
| A07 | Identification and Authentication Failures | {n} |
| A08 | Software and Data Integrity Failures | {n} |
| A09 | Security Logging and Monitoring Failures | {n} |
| A10 | Server-Side Request Forgery | {n} |
| —   | Unmapped | {n} |
```

Only render rows with count > 0, except always show A01-A10 header rows even if zero (so the user sees the audit was comprehensive).

Then detailed findings sections. For each severity bucket present:

```
## 🔴 CRITICAL (N)
- **[scanner] rule** — file:line
  - Description: ...
  - OWASP: A0X (Name) or "unmapped"
  - Suggested fix: <inline, if obvious — e.g., "Rotate this secret immediately and use environment variables", "Update <pkg> to >= X.Y.Z", "Use parameterized queries instead of string concatenation">

## 🟠 HIGH (N)
<same format>

## 🟡 MEDIUM (N) — top 20
<same format, capped at 20 entries; if more, show "... and M more in /tmp/<report>">

## 🔵 LOW — counts only
| Rule | Count |
|------|-------|
| B101 | 12 |
```

For **LOW severity**, don't enumerate individual findings — just a count-per-rule table. Mention the raw report path.

5. **Output cap:** never dump more than 20 findings in any single severity section. If exceeded, truncate and footer with `"... and N more — see /tmp/<report>.json for full list"`.

6. Append install hints and next steps:

```
## Install hints for skipped/missing tools
- <tool>: <hint>
...

## Full reports
- Gitleaks: /tmp/gitleaks-report.json
- Bandit: /tmp/bandit-report.json
- npm audit: /tmp/npm-audit-<dir>.json
- eslint-security: /tmp/eslint-security-<dir>.json

## Next steps
- Run `/ticketing:security --tickets` to create tickets for HIGH/CRITICAL findings (requires `/ticketing:init` to have been run).
- Or address findings manually and re-run the audit.
- For `npm audit` findings, `npm audit fix` may resolve many automatically — but this skill will not run it for you.
```

If ALL scanners ran and `FINDINGS[]` is empty, replace the detail sections with:
> ✅ **No security findings.** All active scanners completed with zero issues.

---

## Phase 8 — Tickets Mode (only if `TICKETS_MODE`)

If `TICKETS_MODE` is false, skip this phase entirely.

1. Verify `<ROOT>/docs/tickets/.config.json` exists. If not, report:
   > `--tickets` requested but ticketing isn't initialized. Run `/ticketing:init` first, then re-run.
   Stop the skill (the report from Phase 7 is still useful on its own).

2. Read the prefix from `.config.json` as `PREFIX`. Read `next_id` as `NEXT_ID`.

3. Filter `FINDINGS[]` to only CRITICAL and HIGH severities. Call this `TO_TICKET[]`.

4. **Deduplicate:** group by `(scanner, rule, file)` — don't create multiple tickets for the same rule in the same file. Keep the first finding per group and note the extra line numbers in the ticket body.

5. For each group, create a ticket by invoking the same logic as `/ticketing:new`:

   a. ID: `<PREFIX>-T<NEXT_ID zero-padded to 3>`. Increment `NEXT_ID` locally after each ticket.

   b. Title: `Security: <rule> in <basename(file)>` (truncate to 80 chars if long).

   c. Slug filename (same rules as `/ticketing:new` — lowercase, non-alphanum → `-`, 40 char cap).

   d. Frontmatter:
      ```yaml
      ---
      id: <ID>
      title: <title>
      status: open
      priority: <critical if CRITICAL, else high>
      type: bug
      owner: joe
      created: <today>
      updated: <today>
      related-pr:
      related-tickets:
      labels: [security, <scanner>]
      ---
      ```

   e. Body:
      ```markdown
      # <title>

      ## Vulnerability
      **Scanner:** <scanner>
      **Rule:** <rule>
      **Severity:** <severity>

      <description>

      ## Location
      - `<file>`:<line>
      <if other occurrences: list them>

      ## OWASP Mapping
      <A0X (Name)> or "Not directly mapped to OWASP Top 10"

      ## Suggested Remediation
      <same inline-fix logic as Phase 7>

      ## Scanner Output
      ```
      <raw JSON entry from the scanner, formatted>
      ```

      ## Acceptance Criteria
      - [ ] Remediation applied
      - [ ] Scanner rerun locally shows finding resolved
      - [ ] No regression in existing tests

      ## Retrospective
      _Fill in when moving to done/._
      ```

   f. Write to `<ROOT>/docs/tickets/open/<filename>`.

6. After all tickets written, update `<ROOT>/docs/tickets/.config.json` with the new `next_id` value.

7. Regenerate `<ROOT>/docs/tickets/INDEX.md` using the same logic as `/ticketing:list` (glob open/in-progress/done, parse frontmatter, write the index). If regeneration fails, warn but don't fail the skill.

8. Append to the chat report:

   ```
   ## Tickets created ({N})
   - <ID>: <title> → docs/tickets/open/<filename>
   - ...
   ```

   If zero tickets were created (because no HIGH/CRITICAL findings existed), append:
   > No HIGH or CRITICAL findings — no tickets created.

---

## Phase 9 — Safety Invariants (reminders, not behaviors)

Before ending, double-check the skill did NOT do any of the following. If it did, something went wrong:

- Modify any `package.json`, `pyproject.toml`, `requirements.txt`, or lockfile
- Run `npm audit fix`, `pip install`, or any other installer
- Auto-commit or push
- Delete any files

The skill is diagnostic + ticket-creation only. All remediation is the user's call.

---

## Phase 10 — Report Done

End the skill response with the Phase 7 report (and the Phase 8 ticket list if applicable). No further action.
