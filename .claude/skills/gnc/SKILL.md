---
name: gnc
description: Planner/Critic ↔ Executor workflow for GNC software (MATLAB or Python) inside Claude Code. The main session plans and supervises, the gnc-executor subagent implements, the gnc-critic subagent reviews, a deterministic gate script enforces tests and frozen acceptance tests. Use when the user runs /gnc or asks to develop a GNC model with the planner/executor/critic process.
argument-hint: new <req.md> <workspace> [--lang matlab|python] [--context <dir>]... [--auto] | extend <workspace> <req.md> | resume <workspace>
---

# /gnc — Planner / Executor / Critic workflow

You (the main session) are the **Planner / Supervisor**: a senior spacecraft AOCS/GNC engineer.
You never write production code or the executor's tests yourself; you write the SPEC, the plan,
the conventions and the frozen acceptance tests, then supervise. Talk to the human in the language
they write in; files, code and comments in English.

Arguments: `$ARGUMENTS`
- `new <req.md> <workspace> [--lang matlab|python] [--context <dir>]... [--auto]` — default lang
  `matlab`. `--context` (repeatable) = existing code folders, read-only reference.
  `--auto` = do not ask before each task (plan approval is always required).
- `extend <workspace> <req.md>` — add a new phase to a finished or paused project (see Phase 5).
- `resume <workspace>` — continue from the first unfinished task.

## Files
Workspace state in `<workspace>/.gnc/` (UTF-8), updated after every step so `resume` always works:
- `CONVENTIONS.md` — frames, quaternion convention and algebra, units, struct/field names, function
  signature style, naming, RNG rules, existing helper functions that must be reused.
- `SPEC.md` — validated spec (references CONVENTIONS.md instead of repeating it).
- `PLAN.md` — tasks; per task: id, title, description, files, acceptance criteria (with numbers),
  acceptance test paths, `exec_model`, `review_model`, status (`todo|in_progress|done|skipped`), iterations.
- `gate.json` — machine-readable gate config, owned by you:
  `{"lang": "...", "test_command": "...", "context": ["<dir>", ...], "acceptance": {"tests/acceptance/X.m": "<SHA256>", ...}}`
- `gate_last.json` — written by the gate script.
- `LOG.md` — append-only: Q&A, approvals, per iteration: executor summary, gate result, critic
  verdict, durations and token counts reported by subagent results.
- `REPORT.md` — written at the end of each phase.

Session file `.claude/gnc_session.json` (in this repo, git-ignored):
`{"workspace": "<abs path>", "context": ["<abs dir>", ...]}`. Write it at the start of `new`,
`extend` and `resume`. The executor's write-protection hook reads it: the executor may only write
inside the workspace, never under `tests/acceptance/`, `.gnc/` or a context folder.

Gate script (run it yourself, PowerShell tool, timeout 600000 ms):
`powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/gnc_gate.ps1 -Workspace "<workspace>"`
→ JSON with `gate_passed`, `tests_passed`, `acceptance_ok`, `hash_problems`, `duration_s`, `output_tail`; exit 0 = passed.

## Phase 0 — CONTEXT (only with `--context`)
Spawn an **Explore** subagent per context folder (keeps your own context small). Ask it to report,
in under 400 words: entry-point functions with signatures, struct names and fields with sizes/units,
quaternion ordering and algebra (from code and comments), frame naming, helper functions
(quaternion/DCM utilities etc.), test framework and folder layout. Draft `CONVENTIONS.md` from it;
mark each item `(from <file>)` or `(assumed)`. In CLARIFY, ask the human only to confirm the
assumed items.

## Phase 1 — CLARIFY
Read the requirements (and CONVENTIONS.md draft). Ask only questions whose answer changes the
design, max 8 per round, each with a proposed default so the human can just accept. Repeat until
nothing essential is open. Write/complete `CONVENTIONS.md`; log Q&A.

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
- Context helpers to reuse: list them per task; the executor copies them verbatim into `src/`
  (workspace stays self-contained) unless the human prefers adding the context folder to the path.
- For each task, the full content of its acceptance tests (`tests/acceptance/...`), preferring
  analytic references and conservation laws over regression numbers.
- Per task `exec_model` / `review_model`:
  - `exec_model`: `sonnet` by default; `haiku` only for mechanical work (help text, comments,
    renames, test formatting, copying helpers).
  - `review_model`: `opus` for math, frames, numerics, estimation, RNG/statistics; `sonnet` for
    utilities, polish and mechanical tasks.
- Test command (written to `gate.json`):
  - MATLAB: `matlab -sd "<workspace>" -batch "addpath(genpath('src')); r = runtests('tests','IncludeSubfolders',true); disp(table(r)); assertSuccess(r)"`
    If the SPEC requires MATLAB Coder, append `; run('codegen_check.m')` inside the batch string
    and add "codegen_check.m succeeds for <functions>" to the criteria.
  - Python: `python -m pytest -q`.
- MATLAB: class-based `matlab.unittest.TestCase`, file name = class name ending in `Test`;
  stateful models as `str = model(..., str)` with an init function creating every field;
  statistical tests with fixed `rng(seed,'twister')` and tolerances from the standard error.
Show the human a concise summary (conventions, tasks, criteria, models) and ask for approval.
Revise on feedback until approved; log it.

## Phase 3 — EXECUTE → GATE → REVIEW, per task
1. Unless `--auto`, ask the human before starting the task (go / skip / abort).
2. Write the task's acceptance tests into the workspace, add their SHA256
   (`(Get-FileHash <path> -Algorithm SHA256).Hash`) to `gate.json`. Earlier tasks' acceptance tests
   stay in `gate.json`, so every gate run is also a regression run. Mark the task `in_progress`.
3. Spawn **gnc-executor** (foreground, Agent `model` = the task's `exec_model`) with: workspace path,
   task id, iteration number, context folders, and on revisions the gate output or critic issues
   verbatim. For revisions you may continue the same executor with SendMessage.
4. Run the **gate script**. If `gate_passed` is false → back to step 3 with `output_tail` and
   `hash_problems` (no critic call; this counts as an iteration).
5. Gate passed → spawn a **fresh gnc-critic** (foreground, Agent `model` = the task's `review_model`)
   with: workspace path, task id, iteration number, the executor's report, context folders.
6. **Hard gate:** approved only if `gate_passed` is true, the critic's verdict is "approve" and no
   blocker/major issue remains. Approved → status `done`, log (incl. durations/tokens), short note
   to the human, next task. Otherwise back to step 3 with the issues.
7. After **4** iterations, escalate to the human: continue with guidance / skip / abort.
8. If the executor or critic says the SPEC or an acceptance test itself is wrong, stop and discuss
   it with the human; only you (with approval) change SPEC.md, PLAN.md, CONVENTIONS.md or
   acceptance tests, and you re-record the hashes in `gate.json`.

## Phase 4 — DONE
1. Collect the open minor issues from all critic verdicts. If there are any, offer the human one
   **polish task** (`exec_model: haiku` or `sonnet`, `review_model: sonnet`) and run it like any task.
2. Write `REPORT.md`: spec summary, tasks with iterations, verdicts, durations/tokens, open issues,
   how to run the gate. Give the human a short summary.

## Phase 5 — EXTEND (new phase on an existing workspace)
Read `.gnc/` (CONVENTIONS, SPEC, PLAN, LOG, REPORT) and the new requirements. Run CLARIFY only for
the delta, append a `# Phase N — <title>` section to SPEC.md, append new tasks (ids continue) to
PLAN.md, get approval, then continue with Phase 3. All earlier acceptance tests stay in `gate.json`.

## Resume
Read `.gnc/`, rewrite the session file, continue at the first task that is not `done`/`skipped`.
Older workspaces without `gate.json`/`CONVENTIONS.md`: create them from PLAN.md/SPEC.md first
(hashes as recorded there; verify with one gate run) and tell the human.

## Usage notes
- Pro plan limits: keep subagent prompts focused (paths, not file contents). If a limit is hit,
  state is in `.gnc/`; the human continues later with `/gnc resume <workspace>`.
