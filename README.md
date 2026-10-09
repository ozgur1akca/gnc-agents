# gnc-agents

A Planner ↔ Executor ↔ Critic workflow for developing spacecraft AOCS/GNC software (sensor and
actuator models, dynamics, estimation) in MATLAB or Python, running natively in
**Claude Code**. It works with a Claude **Pro** subscription; no API key is needed.

| Role | Where | Model | Job |
|---|---|---|---|
| Planner / Supervisor | main session | Opus | Asks clarifying questions, writes the SPEC, the plan and the frozen acceptance tests, runs the process |
| Executor | `.claude/agents/gnc-executor.md` | Sonnet | Implements one task, writes its own tests, runs them |
| Critic | `.claude/agents/gnc-critic.md` | Opus (read-only) | Re-runs the tests itself, verifies acceptance-test hashes, reviews GNC correctness |

```
Questions ──► SPEC + Plan ──(your approval)──► Task: Executor ──► Critic ──(approve)──► next task / Report
                                                      ▲              │
                                                      └──(revise)────┤  not approved after 4 tries → asks you
```

## Usage

1. Copy [examples/req_template.md](examples/req_template.md) and fill it in with your requirements.
   Always list the struct field names of your existing code; the executor only sees files it wrote.
2. Open Claude Code in this folder and type:
   ```
   /gnc new <path to req.md> <workspace folder>
   ```
   Example: `/gnc new D:\reqs\my_sensor.md D:\workspace\projects\my_sensor`.
   Options: `--lang matlab|python` (default `matlab`), `--auto` (do not ask before each task).
3. Answer the questions, approve the plan, follow the tasks.
4. If the session ends or you hit the Pro usage limit: `/gnc resume <workspace folder>`

Claude talks to you in the language you write in; all files and code are in English.

The workspace folder will contain `src/`, `tests/`, `tests/acceptance/` (frozen), `codegen_check.m`
(if code generation is required) and the process state in `.gnc/` (`SPEC.md`, `PLAN.md`, `LOG.md`,
`REPORT.md`).

## Safeguards

- **Frozen acceptance tests:** a hook blocks the executor from writing under `tests/acceptance/`
  ([.claude/hooks/protect_acceptance.ps1](.claude/hooks/protect_acceptance.ps1)); the critic also checks their SHA256 hashes.
- **Hard gate:** a task is not approved unless the tests pass in the critic's own run, the hashes match
  and no blocker/major issue remains.
- **MATLAB:** tests run on your machine with your own license via `matlab -batch` (`matlab` must be on PATH).
  If the SPEC requires code generation, `codegen_check.m` is added to the test command (needs a MATLAB Coder license).

## Requirements

- Claude Code (CLI or IDE extension) with a Claude Pro or higher plan
- Windows with PowerShell (the protection hook is a PowerShell script)
- MATLAB on PATH for MATLAB projects, or Python 3.11+ with pytest for Python projects

## Layout

```
.claude/skills/gnc/SKILL.md          workflow (planner instructions)
.claude/agents/gnc-executor.md       executor agent
.claude/agents/gnc-critic.md         critic agent
.claude/hooks/protect_acceptance.ps1
examples/req_template.md             requirements template
```

## License

[MIT](LICENSE)
