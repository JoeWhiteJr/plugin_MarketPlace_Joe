---
name: status
description: "Show the current dev-cycle state: cycle number, project profile, task board, and history."
---

# Dev-Cycle: Status

You are executing the `status` skill — displaying the current state of the dev-cycle workflow.

---

## Steps

1. **Check for state file**: Read `.workflow/state.json`. If it doesn't exist, report:
   > No active dev-cycle session. Run `/dev-cycle:start` to begin.

   And stop.

2. **Display workflow state**:
   > **Dev Cycle Status**
   >
   > | Field | Value |
   > |-------|-------|
   > | Status | {running/stopped} |
   > | Current Cycle | {N} |
   > | Started | {timestamp} |
   > | Default Branch | {branch} |
   >
   > **Project Profile**
   > | Setting | Value |
   > |---------|-------|
   > | Language | {language} |
   > | Framework | {framework} |
   > | Test Runner | {test_runner} |
   > | Linter | {linter} |
   > | Package Manager | {package_manager} |
   > | CI | {ci} |

3. **Display current task board**: Read `.workflow/tasks.md`. If it exists, display its contents. If not:
   > No active task board (between cycles or not yet started).

4. **Display history summary**: Count files in `.workflow/history/`. If any exist, show:
   > **Cycle History**
   >
   > | Cycle | Tasks | Done | Blocked | PRs |
   > |-------|-------|------|---------|-----|
   > | 1 | 5 | 4 | 1 | 4 |
   > | 2 | 5 | 5 | 0 | 5 |
   > | ... | ... | ... | ... | ... |
   >
   > **Totals**: {X} cycles, {Y} tasks completed, {Z} PRs created

   Pull this data from the `cycle_history` array in state.json.

5. **Show trends** (if 2+ cycles in history):
   > **Trends**
   > - Findings per cycle: {increasing/decreasing/stable}
   > - Block rate: {X}%
   > - Completion rate: {X}%
