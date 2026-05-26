---
name: run-sim
description: Run simulation on the latest testbench
---

Run simulation on the latest testbench.

Steps:
1. Find latest file in outputs/testbenches/
2. Find corresponding RTL file from mental_model/current.json
3. Run: vivado -mode batch -source tools/run_vivado.tcl -tclargs <rtl> <testbench>
4. Parse and display result from outputs/reports/sim_<timestamp>.txt

Quick way to re-run simulation without going through full loop.
