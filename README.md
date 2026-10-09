# gnc-agents

A Planner ↔ Executor ↔ Critic workflow for developing spacecraft AOCS/GNC software (sensor and
actuator models, dynamics, estimation) in MATLAB or Python, running natively in
**Claude Code**. It works with a Claude **Pro** subscription; no API key is needed.

| Role | Where | Model | Job |
|---|---|---|---|
| Planner / Supervisor | main session | Opus | Asks clarifying questions, writes conventions, SPEC, plan and frozen acceptance tests, runs the gate |
| Executor | `.claude/agents/gnc-executor.md` | Sonnet (Haiku for mechanical tasks) | Implements one task, writes its own tests, runs them |
| Gate | `.claude/scripts/gnc_gate.ps1` | — (deterministic) | Verifies acceptance-test hashes and runs the whole test suite |
| Critic | `.claude/agents/gnc-critic.md` | Opus (Sonnet for simple tasks), read-only | Reviews conventions, physics, numerics, codegen and test quality |

```
[Context] ─► Questions ─► CONVENTIONS + SPEC + Plan ─(your approval)─► Task: Executor ─► Gate ─► Critic ─(approve)─► next task
                                                                              ▲          │        │
                                                                              └─(fail)───┘        │
                                                                              └──────(revise)─────┘   4 tries → asks you
```

## Usage

1. Copy [examples/req_template.md](examples/req_template.md) and fill it in with your requirements.
2. Open Claude Code in this folder and type:
   ```
   /gnc new <path to req.md> <workspace folder> [--context <existing code folder>]
   ```
   Example: `/gnc new D:\reqs\gyro.md D:\workspace\projects\gyro --context D:\workspace\my_sim`.
   - `--context` (repeatable): existing code, read-only. Interfaces, struct fields, conventions and
     reusable helpers are extracted from it, so you only confirm instead of typing them.
   - `--lang matlab|python` (default `matlab`), `--auto` (do not ask before each task).
3. Answer the questions, approve the plan, follow the tasks.
4. Add a new phase to an existing project: `/gnc extend <workspace folder> <path to new req.md>`
5. If the session ends or you hit the Pro usage limit: `/gnc resume <workspace folder>`

Claude talks to you in the language you write in; all files and code are in English.

The workspace folder will contain `src/`, `tests/`, `tests/acceptance/` (frozen), `codegen_check.m`
(if code generation is required) and the process state in `.gnc/` (`CONVENTIONS.md`, `SPEC.md`,
`PLAN.md`, `gate.json`, `LOG.md`, `REPORT.md`).

## Safeguards

- **Deterministic gate:** after every executor iteration the planner runs
  [gnc_gate.ps1](.claude/scripts/gnc_gate.ps1), which checks the SHA256 of all frozen acceptance tests
  and runs the whole suite (regression included). The critic is only called when the gate passes.
- **Write protection:** a `PreToolUse` hook ([settings.json](.claude/settings.json),
  [protect_acceptance.ps1](.claude/hooks/protect_acceptance.ps1)) lets the executor write only inside
  the workspace, never under `tests/acceptance/`, `.gnc/` or a context folder.
- **Hard gate:** a task is approved only if the gate passed and the critic approves with no blocker/major issue.
- **MATLAB:** tests run on your machine with your own license via `matlab -batch` (`matlab` must be on PATH).
  If the SPEC requires code generation, `codegen_check.m` is added to the test command (needs a MATLAB Coder license).

## Requirements

- Claude Code (CLI or IDE extension) with a Claude Pro or higher plan
- Windows with PowerShell (hook and gate are PowerShell scripts)
- MATLAB on PATH for MATLAB projects, or Python 3.11+ with pytest for Python projects

## Layout

```
.claude/skills/gnc/SKILL.md          workflow (planner instructions)
.claude/agents/gnc-executor.md       executor agent
.claude/agents/gnc-critic.md         critic agent
.claude/scripts/gnc_gate.ps1         deterministic gate
.claude/hooks/protect_acceptance.ps1 executor write protection
.claude/settings.json                hook registration
examples/req_template.md             requirements template
```

## License

[MIT](LICENSE)
