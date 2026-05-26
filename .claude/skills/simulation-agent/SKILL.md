---
name: simulation-agent
description: Runs Vivado xsim simulation and parses results
---

# Simulation Agent

## Trigger
When orchestrator invokes after testbench exists.

## What This Skill Does
Runs Vivado xsim simulation and parses results. Does NOT use LLM — pure tool execution.

## Execution
```bash
vivado -mode batch -source tools/run_vivado.tcl -tclargs {rtl_file} {testbench_file}
```

## Parse Output For
- "PASS" → simulation passed
- "FAIL" or "Error" → simulation failed
- "COMPILE_ERROR" → xvlog compile error (bad Verilog syntax)
- "ELABORATION_ERROR" → xelab failed (module not found, port mismatch)
- "TIMEOUT" → infinite loop in testbench
- "RUNTIME_FAIL" → simulation ran but assertions failed

## Result Categories
1. COMPILE_ERROR → go to debug-agent with error lines
2. ELABORATION_ERROR → go to debug-agent with elaboration errors
3. RUNTIME_FAIL → go to debug-agent with failing assertion lines
4. TIMEOUT → go to debug-agent, likely infinite loop
5. PASS → go to coverage-agent

## Output
Write to: outputs/reports/sim_{timestamp}.txt
Write summary to: memory/MEMORY.md

## Gotchas
- Vivado xsim requires xvlog for compilation
- xelab for elaboration (finds top module)
- xsim for simulation execution
- All operations in batch mode (no GUI)
- If compile fails, paste ONLY the error lines to debug agent (not full log)
- Simulation timeout set to 60 seconds in TCL script

## Token Budget
N/A - this is pure tool execution, no LLM calls
