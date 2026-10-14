# CLAUDE.md — gnc-agents

Context for Claude Code. The owner works on spacecraft AOCS/GNC (attitude determination &
control). Reply in the language the user writes in (Turkish or English). Everything in the repo
(code, comments, docs, prompts, templates) is in **English**; the repo is public.

## What this project is
A Planner ↔ Executor ↔ Critic workflow for developing GNC software (sensor/actuator models,
dynamics, EKF/UKF/MEKF) in **MATLAB or Python**, running natively in Claude Code on the owner's
**Pro plan** (no API key). Started with `/gnc` (`.claude/skills/gnc/SKILL.md`):
- Main session (Opus) = Planner/Supervisor: environment check, optional context extraction
  (`--context`, Explore subagent) → clarify → CONVENTIONS + SPEC + plan with validated staged
  acceptance tests (human approves) → per task: freeze tests, executor, git-based change check,
  deterministic gate, fresh critic. Also `extend`, `resume`, change requests, `--commit`.
- `.claude/agents/gnc-executor.md` (Sonnet; per-task `exec_model`, Haiku for mechanical tasks;
  task types `impl|tuning|diagnose|polish`, tuning/diagnose with an explicit budget).
- `.claude/agents/gnc-critic.md` (Opus; per-task `review_model`, read-only): reviews only after the
  gate passed, does not re-run the suite; returns a JSON verdict.
- `.claude/scripts/gnc_gate.ps1 -Workspace <ws> [-Slow]`: reads `<ws>/.gnc/gate.json`
  (`test_command`, `slow_command`, `timeout_s`, `frozen` + legacy `acceptance` hashes), verifies
  hashes, runs the command via `Start-Process` + `-EncodedCommand` (PowerShell 5.1 mangles embedded
  quotes), timeout → kills the tree, kills leftover descendants, keeps the machine awake
  (SetThreadExecutionState); writes `gate_last.json`; exit 0 = passed.
- Session registry: the planner runs `.claude/scripts/gnc_session.ps1 -Workspace <ws> -Context ...`,
  which writes `.claude/gnc_sessions/<CLAUDE_CODE_SESSION_ID>.json` (git-ignored). Hook input
  `session_id` of a subagent equals the parent session id (verified), so parallel /gnc sessions work.
- Executor hooks (`.claude/settings.json`, only when hook input `agent_type == "gnc-executor"`):
  `protect_acceptance.ps1` (PreToolUse Write/Edit: inside workspace only; never `tests/acceptance/`,
  `.gnc/`, frozen files, context; no registered session → deny) and `check_shell_writes.ps1`
  (Pre/PostToolUse PowerShell|Bash: reports files changed outside the workspace in the gnc-agents
  repo, context folders, session scratchpad, plus frozen/.gnc files; exit 2 feedback, cannot undo).
  **`hooks:` in agent frontmatter does NOT fire (verified, v2.1.292); keep hooks in settings.json.**
  Settings hooks reload live and fire for subagent tool calls.
- State per project in `<workspace>/.gnc/` (CONVENTIONS, SPEC, PLAN, acceptance/, gate.json,
  gate_last.json, LOG, REPORT); executor scratch in `<workspace>/.scratch/`.
  Max 4 iterations per task, then human escalation (continue / park / skip / abort).

The earlier Python API-based framework was archived outside the repo at
`D:\workspace\_archive\gnc-agents-python`.

## MATLAB specifics
- Test command: `matlab -sd "<workspace>" -batch "addpath(genpath('src')); r = runtests('tests','IncludeSubfolders',true); disp(table(r)); assertSuccess(r)"`.
  `-batch` has no JVM (no Java classes).
- Codegen gate: if SPEC requires MATLAB Coder, append `; run('codegen_check.m')`.
- MATLAB R2026b at `C:\Program Files\MATLAB\R2026b\bin` (on PATH), MATLAB Coder installed.

## Owner's ADCS conventions (for MATLAB work)
- Quaternion **scalar-last** [q1 q2 q3 q4], Markley/passive (`qtn2A`); q_B/I, w_B/I in rad/s.
- Sensor models are MATLAB functions taking the dynamics struct and the sensor's own struct
  (config + internal variables); codegen-compatible when required.
- Owner's ADCS library (read-only context): `D:\workspace\adcs`.

## Projects built with /gnc
The owner's /gnc projects live in sibling folders under `D:\workspace\`; their `.gnc/LOG.md` files
are the main source of lessons for this repo. When reviewing a project another chat may be using,
stay read-only.

## Notes
- Hook tests must use scratch folders, never the owner's real projects.
- The repo is public: keep examples generic, no project-specific requirements.
