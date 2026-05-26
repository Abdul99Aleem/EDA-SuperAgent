---
name: mental-model-builder
description: Builds structured JSON mental model from RTL and specs - ground truth for verification
---

# Mental Model Builder

## Trigger
When user asks to build mental model OR when orchestrator invokes this skill.
This is the MOST IMPORTANT skill. Do not skip it.

## What Is a Mental Model
From Cadence ChipStack paper:
"The Mental Model provides the ground truth for chip behavior intention and goals."
It is NOT text. It is structured JSON that encodes:
- Module hierarchy
- Port connectivity and interface types
- Timing constraints
- Expected behavior assertions
- Design parameters

Test correctness jumps from 42% to 83% when this is built correctly.

## Process (Elaborate → Enrich → Reason)
1. ELABORATE: Extract raw structure from RTL
   - Run: python3 tools/parse_rtl.py inputs/rtl/<file>.v
   - Extract: module names, port lists, parameters

2. ENRICH: Add interface and protocol info from spec
   - Read: inputs/specs/design.txt
   - Add: interface types (AXI-Lite, AXI4, APB, custom)
   - Add: protocol constraints (burst_len, alignment, timing)

3. REASON: Derive expected behavior
   - From hierarchy + connectivity → infer data flow
   - From spec assertions → encode expected_behavior list

## Output Format
Write to: mental_model/current.json

Schema:
{
  "design_name": "string",
  "build_date": "ISO timestamp",
  "rtl_files": ["list of source files"],
  "modules": [
    {
      "name": "string",
      "type": "top | sub | ip",
      "ports": {
        "inputs": [{"name": "clk", "width": 1}],
        "outputs": [{"name": "data_out", "width": 32}]
      },
      "parameters": {"DATA_WIDTH": 32},
      "submodules": ["list of child module names"]
    }
  ],
  "interfaces": [
    {
      "type": "AXI-Lite | AXI4 | APB | custom",
      "master": "module_name",
      "slave": "module_name",
      "data_width": 32,
      "addr_width": 32
    }
  ],
  "constraints": [
    "burst_length <= 256",
    "addresses must be 4-byte aligned"
  ],
  "expected_behavior": [
    "transfer completes within 16 cycles",
    "interrupt fires exactly once per transfer"
  ],
  "hierarchy": {
    "top": "module_name",
    "depth": 2,
    "tree": {}
  }
}

## Gotchas
- If RTL uses parameters not in spec, ask user to clarify before proceeding
- AXI signals: always check if READY/VALID handshake is symmetric
- Do not infer expected_behavior from RTL alone — always cross-check with spec
- If spec is ambiguous, write a question to outputs/reports/spec_questions.txt

## Token Budget
Keep context minimal:
- Parse RTL with parse_rtl.py (don't read full .v files)
- Extract only key assertions from spec (not full text)
- Total context: <1500 tokens
