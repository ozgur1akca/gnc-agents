# CLAUDE.md — gnc-agents

Context for Claude Code. The owner works on spacecraft AOCS/GNC (attitude determination &
control). Reply in the language the user writes in (Turkish or English). Everything in the repo
(code, comments, docs, prompts, templates) is in **English**; the repo is public.

## What this project is
A Planner ↔ Executor ↔ Critic workflow for developing GNC software (sensor/actuator models,
dynamics, EKF/UKF/MEKF) in **MATLAB or Python**, running natively in Claude Code on the owner's
**Pro plan** (no API key). Started with `/gnc` (`.claude/skills/gnc/SKILL.md`):
- Main session (Opus) = Planner/Supervisor: optional context extraction (`--context`, via Explore
  subagent) → clarify → CONVENTIONS + SPEC + plan (human approves) → per task: frozen acceptance
  tests, executor, deterministic gate, fresh critic. Also `extend` (new phase) and `resume`.
- `.claude/agents/gnc-executor.md` (Sonnet; per-task `exec_model`, Haiku for mechanical tasks).
- `.claude/agents/gnc-critic.md` (Opus; per-task `review_model`, read-only): reviews only after the
  gate passed, does not re-run the suite; returns a JSON verdict.
- `.claude/scripts/gnc_gate.ps1 -Workspace <ws>`: reads `<ws>/.gnc/gate.json` (test_command,
  acceptance hashes), verifies hashes, runs the suite, writes `gate_last.json`; exit 0 = passed.
  Runs the test command via `-EncodedCommand` because PowerShell 5.1 mangles embedded quotes.
- Write protection: `.claude/settings.json` PreToolUse hook → `.claude/hooks/protect_acceptance.ps1`.
  It acts only when hook input `agent_type == "gnc-executor"`; allowed = inside the workspace from
  `.claude/gnc_session.json` (git-ignored, written by the planner), never `tests/acceptance/`,
  `.gnc/` or context folders. **`hooks:` in agent frontmatter does NOT fire (verified, v2.1.292);
  keep hooks in settings.json.** Settings hooks reload live and fire for subagent tool calls.
- State per project in `<workspace>/.gnc/` (CONVENTIONS, SPEC, PLAN, gate.json, gate_last.json,
  LOG, REPORT). Max 4 iterations per task, then human escalation.

The earlier Python API-based framework was archived outside the repo at
`D:\workspace\_archive\gnc-agents-python`.

## MATLAB specifics
- Test command: `matlab -sd "<workspace>" -batch "addpath(genpath('src')); r = runtests('tests','IncludeSubfolders',true); disp(table(r)); assertSuccess(r)"`.
- Codegen gate: if SPEC requires MATLAB Coder, append `; run('codegen_check.m')`.
- MATLAB R2026b at `C:\Program Files\MATLAB\R2026b\bin` (on PATH). A 46-test suite takes ~25 s.

## Owner's ADCS conventions (for MATLAB work)
- Quaternion **scalar-last** [q1 q2 q3 q4]; q_B/I, w_B/I in rad/s.
- Sensor models are MATLAB functions taking the dynamics struct and the sensor's own struct
  (config + internal variables); must be **codegen-compatible**.

## Status / next steps
- A first `/gnc` run (older workflow) built the owner's star tracker model at
  `D:\workspace\gnc_star_tracker` (5 tasks, all approved at iteration 1, 46/46 tests).
- Next: validate the new workflow on a new sensor (e.g. gyro) with
  `--context D:\workspace\gnc_star_tracker`. Then use LOG durations/tokens to decide where Haiku fits.
- Hook tests must use scratch folders, never the owner's real projects.
- The repo is public: keep examples generic, no project-specific requirements.
