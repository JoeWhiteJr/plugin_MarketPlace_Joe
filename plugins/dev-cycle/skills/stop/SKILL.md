---
name: stop
description: "Gracefully stop the dev-cycle continuous improvement loop."
---

# Dev-Cycle: Stop

You are executing the `stop` skill — gracefully shutting down the dev-cycle workflow.

---

## Steps

1. **Check for state file**: Read `.workflow/state.json`. If it doesn't exist, report:
   > No active dev-cycle session to stop.

   And stop.

2. **Check current status**: If already stopped:
   > Dev cycle is already stopped (stopped at {stopped_at}).

   And stop.

3. **Update state**: Modify `.workflow/state.json`:
   - Set `"status"` to `"stopped"`
   - Add `"stopped_at"` with the current ISO timestamp

4. **Display final report**:
   > **Dev Cycle Stopped**
   >
   > | Metric | Value |
   > |--------|-------|
   > | Total Cycles | {N} |
   > | Total Tasks | {sum of all tasks} |
   > | Tasks Completed | {sum of completed} |
   > | Tasks Blocked | {sum of blocked} |
   > | PRs Created | {sum of PRs} |
   > | Started | {started_at} |
   > | Stopped | {stopped_at} |

   If there are blocked tasks from the last cycle, list them:
   > **Blocked Tasks (may need attention):**
   > - [P{x}] {task title} — {reason}

5. **Remind about PRs**:
   > Don't forget to review and merge the open PRs from this session.
   > Run `gh pr list` to see them.
