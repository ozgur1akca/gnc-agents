# <Model / module name> — <MATLAB | Python>

<!--
Copy this template, fill in the angle brackets, delete lines you do not need.
The clearer you are, the fewer questions the planner asks. Leave uncertain items empty;
the planner will ask about them and propose a default.
You may write this file in any language. Start with: /gnc new <this file> <workspace> [--lang matlab|python]
-->

## Goal
<What is being developed and in which simulation / flight software will it be used? 1–3 sentences.>
<Scope of this phase: only ... in the first phase; ... is left for later phases.>

## Existing structure (interfaces that must not change)
<!-- The executor only sees files it wrote itself; describe your existing code here. -->
- Inputs: <e.g. dynamics struct `sim.dyn` — fields: `q_BI` [4x1], `w_BI` [3x1] rad/s, `t` [s]>
- The model's own struct: <e.g. `sim.<model>` — configuration + internal state fields>
- Outputs: <field names, sizes, units>
- Function signature: <e.g. `[y, st] = model_step(in, st)` and `st = model_init(cfg)`>

## Conventions
- Quaternion: <scalar-last [q1 q2 q3 q4] | scalar-first>, <Hamilton | JPL>, <from which frame to which>
- Frames: <inertial (ECI J2000), body, sensor/actuator mounting frames>
- Units: <SI, angles in rad>; time: <sample period, time scale>

## Requirements
- <Functional requirement 1>
- <Functional requirement 2>
- <Error/noise models, their parameters and where they come from (configuration struct)>

## Constraints
- <Will be converted to C with MATLAB Coder: must be codegen-compatible, codegen check is part of acceptance>
- <Allowed toolboxes / libraries>
- <Performance, fixed-size memory, random number generation and reproducibility (seed)>

## Verification expectations
<!-- Give numeric tolerances where possible; analytic references and conservation laws make the best tests. -->
- <Comparison with an analytic case, e.g. known solution at constant angular rate, tolerance ...>
- <Edge cases, e.g. start-up behaviour, parameters at zero / extreme values>
- <Conservation / property checks, e.g. unit norm, energy, angular momentum>
- <Statistical tests for noise models, e.g. sample std within ±4σ>

## Out of scope
- <Things not done in this phase>
