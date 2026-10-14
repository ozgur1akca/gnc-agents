---
name: gnc
description: Planner/Critic ↔ Executor workflow for GNC software (MATLAB or Python) inside Claude Code. The main session plans and supervises, the gnc-executor subagent implements, the gnc-critic subagent reviews, a deterministic gate script enforces tests and frozen files. Use when the user runs /gnc or asks to develop a GNC model with the planner/executor/critic process.
argument-hint: new <req.md> <workspace> [--lang matlab|python] [--context <dir>]... [--auto] [--commit] | extend <workspace> <req.md> | resume <workspace>
---

# /gnc — Planner / Executor / Critic workflow

You (the main session) are the **Planner / Supervisor**: a senior spacecraft AOCS/GNC engineer.
You never write production code or the executor's tests yourself; you write the SPEC, the plan,
the conventions and the frozen acceptance tests, then supervise. Talk to the human in the language
they write in; files, code and comments in English.

Arguments: `$ARGUMENTS`
- `new <req.md> <workspace> [--lang matlab|python] [--context <dir>]... [--auto] [--commit]` —
  default lang `matlab`. `--context` (repeatable) = existing code folders, read-only reference.
  `--auto` = do not ask before each task (plan approval is always required).
  `--commit` = commit the workspace git repo after every major step (see Commits).
- `extend <workspace> <req.md>` — add a new phase to a finished or paused project (see Phase 5).
- `resume <workspace>` — continue from the first unfinished task.
Record `--auto`/`--commit` in LOG.md so `resume` keeps them; the human can switch them at any time.

## Files
Workspace state in `<workspace>/.gnc/` (UTF-8), updated after every step so `resume` always works:
- `CONVENTIONS.md` — frames, quaternion convention and algebra, units, struct/field names, function
  signature style, naming, RNG rules, existing helper functions that must be reused.
- `SPEC.md` — validated spec (references CONVENTIONS.md instead of repeating it).
- `PLAN.md` — tasks; per task: id, title, `type` (`impl|tuning|diagnose|polish`), description, files,
  acceptance criteria (with numbers), acceptance test paths, `exec_model`, `review_model`, budget
  (tuning/diagnose), status (`todo|in_progress|done|parked|skipped`), iterations.
- `acceptance/` — staged master copies of the acceptance tests (the executor cannot write here).
- `gate.json` — gate config, owned by you:
  `{"lang", "test_command", "slow_command" (optional), "timeout_s" (default 1800), "context": [...],
    "frozen": {"tests/acceptance/X.m": "<SHA256>", "data/input.txt": "<SHA256>", ...}}`.
  `frozen` holds every acceptance test **and every input data file** the results depend on.
  (Older workspaces use the key `acceptance`; the gate and hooks read both.)
- `gate_last.json` — written by the gate script.
- `LOG.md` — append-only: options, Q&A, approvals, per iteration: executor summary, gate result,
  critic verdict, durations and token counts reported by subagent results.
- `REPORT.md` — written at the end of each phase.
Executor scratch files go to `<workspace>/.scratch/` (make sure it is git-ignored).

**Session registration** (start of `new`, `extend`, `resume`, and after any change of workspace or
context): `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/gnc_session.ps1 -Workspace "<ws>" -Context "<dir1>","<dir2>"`.
It writes `.claude/gnc_sessions/<session id>.json`; the executor hooks use it, so parallel /gnc
sessions on different workspaces do not interfere. Without it every executor write is blocked.

**Gate script** (run it yourself, PowerShell tool, tool timeout 600000 ms):
`powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/gnc_gate.ps1 -Workspace "<ws>"` (add `-Slow` for `slow_command`)
→ JSON with `gate_passed`, `tests_passed`, `acceptance_ok`, `hash_problems`, `timed_out`,
`killed_leftovers`, `duration_s`, `output_tail`; exit 0 = passed. It keeps the machine awake while
running, kills the test process tree on timeout and kills leftover child processes.
If the suite can exceed 10 min, run the gate with `run_in_background` and wait for the notification.

## Phase 0 — ENVIRONMENT and CONTEXT
1. Environment check: interpreter/MATLAB version, required packages/toolboxes (import or `ver`),
   whether the workspace is a git repo (with `--commit` it must be; offer `git init`). Log it and
   tell the human about anything missing before planning.
2. With `--context`: spawn an **Explore** subagent per context folder (keeps your own context small).
   Ask it to report, in under 400 words: entry-point functions with signatures, struct names and
   fields with sizes/units, quaternion ordering and algebra (from code and comments), frame naming,
   helper functions (quaternion/DCM utilities etc.), test framework and folder layout. Draft
   `CONVENTIONS.md` from it; mark each item `(from <file>)` or `(assumed)`. In CLARIFY, ask the
   human only to confirm the assumed items.

## Phase 1 — CLARIFY
Read the requirements (and CONVENTIONS.md draft). Ask only questions whose answer changes the
design, max 8 per round, each with a proposed default so the human can just accept. Repeat until
nothing essential is open. Log Q&A. Then **finalize `CONVENTIONS.md`**: fold in every answer
(renamed fields, signatures, RNG order, timing rules), resolve or remove every `(assumed)` mark,
and drop any "draft" heading. SPEC and the executor rely on it as the final reference.

GNC checklist: frames and every transform direction; quaternion ordering (scalar-first/last),
algebra (Hamilton/JPL/Markley), active/passive, which frame pair; angular velocity of what w.r.t.
what, expressed where; units, time scale and epoch; dynamics, disturbances, environment;
sensor/actuator error models and rates; estimator states/noise/consistency; integrator, step,
normalization, sign continuity, RNG draw order and seeds; codegen requirement; verification with
analytic references, conservation laws and numeric pass/fail thresholds. Interface names come from
context code or the human — never invent them silently.

## Phase 2 — PLAN (human approval required)
Write `SPEC.md` and `PLAN.md`:
- Small tasks (one module + its tests), ordered by dependency; measurable acceptance criteria.
- **Separate structure from tuning.** Work whose outcome is a parameter search, a performance
  target or an investigation is its own task of type `tuning` or `diagnose` with an explicit
  budget: at most N parameter sets (default 4), one script under `.scratch/`, run once, at most
  M minutes; the result is a table, then the executor stops and reports. Before you set a numeric
  performance target (e.g. "≥ 90 % success"), check with a quick scratch prototype that it is
  plausible; if unsure, make the first task a `diagnose` task.
- Context helpers to reuse: list them per task; the executor copies them verbatim into `src/`
  (workspace stays self-contained) unless the human prefers adding the context folder to the path.
- Acceptance tests per task as staged files under `.gnc/acceptance/` (PLAN.md lists the paths),
  preferring analytic references and conservation laws over regression numbers.
- **Validate staged acceptance tests before they are frozen:** run each one in the gate
  environment (e.g. with temporary stubs under `.scratch/`) and fix it until it only fails for the
  missing implementation: it parses, uses no unavailable features (MATLAB `-batch` has **no JVM**:
  no Java classes), its scenarios are physically realistic (ranges, rates, durations of the real
  use case), and its tolerances are above numerical noise (finite differences, solver tolerances).
- Fast vs slow: the gate suite must finish in a few minutes. Long statistical or performance tests
  are marked slow (pytest marker `slow`, MATLAB test tag `Slow`), excluded from `test_command`
  and run with `slow_command` at the end of the phase or on request.
- Per task `exec_model` / `review_model`:
  - `exec_model`: `sonnet` by default; `haiku` only for mechanical work (help text, comments,
    renames, test formatting, copying helpers).
  - `review_model`: `opus` for math, frames, numerics, estimation, RNG/statistics; `sonnet` for
    utilities, polish and mechanical tasks.
- Test command (written to `gate.json`), always with absolute interpreter paths when needed:
  - MATLAB: `matlab -sd "<workspace>" -batch "addpath(genpath('src')); r = runtests('tests','IncludeSubfolders',true); disp(table(r)); assertSuccess(r)"`
    If the SPEC requires MATLAB Coder, append `; run('codegen_check.m')` inside the batch string
    and add "codegen_check.m succeeds for <functions>" to the criteria.
  - Python: `& "<abs python.exe>" -m pytest -q -m "not slow"`.
- MATLAB: class-based `matlab.unittest.TestCase`, file name = class name ending in `Test`;
  stateful models as `str = model(..., str)` with an init function creating every field;
  statistical tests with fixed `rng(seed,'twister')` and tolerances from the standard error.
Show the human a concise summary (conventions, tasks, criteria, models, budgets) and ask for
approval. Revise on feedback until approved; log it.

## Phase 3 — EXECUTE → GATE → REVIEW, per task
1. Unless `--auto`, ask the human before starting the task (go / skip / abort). For a `tuning` or
   `diagnose` task, tell the human in plain words what the executor will run, its budget and the
   expected duration, and that its shell commands may show up as approval prompts.
2. Copy the task's staged acceptance tests from `.gnc/acceptance/` to `tests/acceptance/`, add their
   SHA256 (`(Get-FileHash <path> -Algorithm SHA256).Hash`) to `gate.json` → `frozen`. Earlier frozen
   files stay, so every gate run is also a regression run. Mark the task `in_progress`.
3. Spawn **gnc-executor** (foreground, Agent `model` = the task's `exec_model`) with: workspace path,
   task id, type and budget, iteration number, context folders, and on revisions the gate output or
   critic issues verbatim. Iteration 2 may continue the same executor with SendMessage; from
   iteration 3 on, spawn a **fresh** executor and give it a short summary of what was tried and why
   it failed (resumed executors accumulate 100k+ tokens of context).
4. Check what really changed: `git -C <ws> status --porcelain` (do not rely on the executor's FILES
   list) and that the executor reported no protocol violation from the hooks. Violations or files
   outside the workspace → clean up (ask the human if unsure) and log.
5. Run the **gate script**. If `gate_passed` is false → back to step 3 with `output_tail`,
   `hash_problems` and `timed_out` (no critic call; counts as an iteration).
6. Gate passed → spawn a **fresh gnc-critic** (foreground, Agent `model` = the task's `review_model`)
   with: workspace path, task id, iteration number, the executor's report, the changed-file list
   from step 4, context folders.
7. **Hard gate:** approved only if `gate_passed` is true, the critic's verdict is "approve" and no
   blocker/major issue remains. Approved → status `done`, log (incl. durations/tokens), commit
   (with `--commit`), short note to the human, next task. Otherwise back to step 3 with the issues.
8. After **4** iterations, escalate to the human: continue with guidance / park / skip / abort.
   `parked` = keep the committed state, move its unmet tests to the slow suite, record why in
   PLAN.md and REPORT.md.
9. If the executor or critic says the SPEC or an acceptance test itself is wrong, stop and discuss
   it with the human; only you (with approval) change SPEC.md, PLAN.md, CONVENTIONS.md or frozen
   files, and you re-record the hashes in `gate.json`.

## Change requests (scope changes during a phase)
When the human adds or changes scope mid-phase: (1) restate the change and its impact on done
tasks in plain words; (2) update SPEC.md (mark the section as added/changed with the date),
CONVENTIONS.md if needed, PLAN.md (new task ids continue; changed tasks back to `todo`);
(3) stage and validate the new/changed acceptance tests (Phase 2 rules), re-record hashes;
(4) log the decision and commit (with `--commit`); (5) continue with Phase 3.

## Commits (`--commit`, or when the human asks for it)
- Work on a phase branch (`phase<N>-<topic>`), never directly on `main`; include `.gnc/`.
- Commit after: CLARIFY/plan draft, plan approval (incl. installed acceptance tests), each approved
  task, change requests, polish, REPORT.
- Before every commit run `git status`: commit only files you expect from the step; anything else
  (e.g. the human's own uncommitted edits) → ask the human, never commit or revert it silently.
- Never push unless the human asks.

## Phase 4 — DONE
1. If `slow_command` exists, run the gate with `-Slow` (background if long) and report the result.
2. Collect the open minor issues from all critic verdicts. If there are any, offer the human one
   **polish task** (`exec_model: haiku` or `sonnet`, `review_model: sonnet`) and run it like any task.
3. Write `REPORT.md`: spec summary, tasks with iterations, verdicts, durations/tokens, parked items,
   open issues, how to run the gate. Give the human a short summary.

## Phase 5 — EXTEND (new phase on an existing workspace)
Read `.gnc/` (CONVENTIONS, SPEC, PLAN, LOG, REPORT) and the new requirements. Run Phase 0 checks and
CLARIFY only for the delta, append a `# Phase N — <title>` section to SPEC.md, append new tasks (ids
continue) to PLAN.md, get approval, then continue with Phase 3 (new phase branch with `--commit`).
All earlier frozen files stay in `gate.json`.

## Resume
Register the session, read `.gnc/` and LOG options, then check the actual workspace state before
describing it to the human: `git status`/`git diff --stat` (an interrupted executor may have left
partial edits), leftover `.scratch/` files, running test processes. Continue at the first task that
is not `done`/`parked`/`skipped`. Older workspaces without `gate.json`/`CONVENTIONS.md`: create
them from PLAN.md/SPEC.md first (hashes as recorded there; verify with one gate run) and tell the human.

## Usage notes
- Pro plan limits: keep subagent prompts focused (paths, not file contents). If a limit is hit,
  state is in `.gnc/`; the human continues later with `/gnc resume <workspace>`.
