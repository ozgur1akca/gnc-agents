# CLAUDE.md — gnc-agents

Context for Claude Code. The owner works on spacecraft AOCS/GNC (attitude determination &
control) and communicates in **Turkish**; reply in Turkish, keep code/comments in English.

## What this project is
A Planner ↔ Executor ↔ Critic workflow for developing GNC software (sensor/actuator models,
dynamics, EKF/UKF/MEKF) in **MATLAB or Python**, running natively in Claude Code on the owner's
**Pro plan** (no API key). Started with `/gnc` (`.claude/skills/gnc/SKILL.md`):
- Main session (Opus) = Planner/Supervisor: clarify → SPEC + plan (human approves) → per task
  writes frozen acceptance tests, spawns executor, then a fresh critic, enforces the hard gate.
- `.claude/agents/gnc-executor.md` (Sonnet): implements one task, writes own tests, runs them.
- `.claude/agents/gnc-critic.md` (Opus, read-only): re-runs tests, checks SHA256 of acceptance
  tests, reviews conventions/physics/codegen, returns a JSON verdict.
- Frozen acceptance tests: executor-scoped PreToolUse hook `.claude/hooks/protect_acceptance.ps1`
  (exit 2 on writes under `tests/acceptance/`) + critic hash check.
- State per project in `<workspace>/.gnc/` (SPEC.md, PLAN.md, LOG.md, REPORT.md) →
  `/gnc resume <workspace>`. Max 4 iterations per task, then human escalation.

The earlier Python API-based framework (`gnc_agents/` package, `gnc-agents` CLI) was archived
outside the repo at `D:\workspace\_archive\gnc-agents-python`.

## MATLAB specifics
- Tests run on the owner's machine with their license:
  `matlab -sd "<workspace>" -batch "addpath(genpath('src')); r = runtests('tests','IncludeSubfolders',true); disp(table(r)); assertSuccess(r)"`.
- Codegen gate: if SPEC requires MATLAB Coder, append `; run('codegen_check.m')`; executor
  maintains it with `codegen(fn,'-config',coder.config('lib'),'-args',{...})`.
- MATLAB R2026b at `C:\Program Files\MATLAB\R2026b\bin` (on PATH).

## Owner's ADCS conventions (for MATLAB work)
- Quaternion **scalar-last** [q1 q2 q3 q4]; q_B/I, w_B/I in rad/s.
- Sensor models are MATLAB functions taking the dynamics struct and the sensor's own struct
  (config + internal variables); must be **codegen-compatible**.
- Star tracker delay = integer sensor samples + small random sub-sample delay, via a buffer.

## Status / next steps
- First real run pending: star tracker delay model (`examples/matlab_star_tracker/req.md`).
  Field names of `sim.dyn` / `sim.str` in req.md still need to be filled in by the owner.
- Executor-scoped hook in agent frontmatter not yet verified in a live run.
