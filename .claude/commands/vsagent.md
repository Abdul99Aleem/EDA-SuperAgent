---
name: vsagent
description: Run the full VLSI Super Agent verification loop
---

Run the full VLSI Super Agent verification loop.

Steps:
1. Confirm inputs/rtl/ has .v files and inputs/specs/design.txt exists
2. Invoke orchestrator skill
3. Report final result: PASS / FAIL / ESCALATE_TO_HUMAN

This command triggers the complete flow:
- Build/update mental model
- Generate test plan
- Generate testbench
- Run simulation
- Analyze coverage
- Debug if needed
- Generate documentation
