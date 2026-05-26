---
name: orchestrator
description: VLSI Super Agent main loop - coordinates all sub-agents for verification
---

# Orchestrator — VLSI Super Agent Loop

## Trigger
When user runs /vsagent or asks to "run the full verification loop"

## What This Skill Does
Coordinates all sub-agents in order to complete one full verification iteration.
This is the Super Agent from the Cadence ChipStack architecture.

## Pre-conditions (check before starting)
1. inputs/rtl/ contains at least one .v file
2. inputs/specs/ contains design.txt
3. mental_model/current.json exists OR needs to be built (go to Step 1)
4. Ollama is running: `curl http://localhost:11434/api/tags`

## Execution Steps

### STEP 1: Mental Model
- Invoke skill: mental-model-builder
- Input: all files in inputs/rtl/ + inputs/specs/design.txt
- Output: mental_model/current.json
- Validation: JSON must have modules, interfaces, constraints, expected_behavior

### STEP 2: Test Planning
- Invoke skill: test-plan-agent
- Input: mental_model/current.json
- Primary model: Qwen2.5-Coder
- Review model: Mistral
- Output: outputs/test_plans/plan_<timestamp>.md

### STEP 3: Testbench Generation
- Invoke skill: codegen-agent
- Input: mental_model/current.json + test plan
- Primary model: Qwen2.5-Coder
- Review model: Mistral
- Output: outputs/testbenches/tb_<module>.v

### STEP 4: Simulation
- Invoke skill: simulation-agent
- Tool: vivado -mode batch -source tools/run_vivado.tcl
- Output: outputs/reports/sim_<timestamp>.txt
- Parse: PASS / FAIL + error lines

### STEP 5: Coverage Analysis
- Invoke skill: coverage-agent
- Input: simulation results
- Output: outputs/reports/coverage_<timestamp>.txt

### STEP 6: Debug (only if FAIL)
- Invoke skill: debug-agent
- Input: error lines (max 10) + mental model context
- Primary model: Qwen2.5-Coder
- Review model: Mistral
- Output: patched testbench → go back to STEP 4
- Max retries: 3 before flagging human

### STEP 7: Documentation
- Invoke skill: vlsi-doc-writer
- Input: what was verified + mental model
- Output: outputs/docs/<topic>_<date>.md

## State Machine
IDLE → BUILD_MODEL → PLAN → GENERATE → SIMULATE → COVERAGE → (PASS→DOC | FAIL→DEBUG→GENERATE)

## Memory Update (after every step)
Ask Claude to write findings to memory/ using auto memory.
Specifically: "Remember that [finding] for [module]"

## Phase 1 Scope
Currently implementing: mental model → test plan → codegen → simulation → coverage
NOT implementing yet: advanced stimulus, assertion, result-analyzer agents
