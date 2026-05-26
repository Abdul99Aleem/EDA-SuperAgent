---
name: debug-agent
description: Diagnoses simulation failures and proposes fixes using dual-model review
---

# Debug Agent

## Trigger
When simulation fails. Read gotchas.md in this skill folder FIRST.

## Input (keep minimal — your CPU is slow)
- Error snippet: MAX 10 lines from simulation log
- Module context: name + interface type from mental model
- Past similar fixes: search memory/fixes.log for module name

## Dual-Model Process
1. Qwen2.5-Coder diagnoses root cause + proposes fix
2. Mistral validates the fix is correct RTL/Verilog
3. Qwen applies patch to testbench

## Qwen Debug Prompt (STRICT — under 400 tokens)
System: You are a Verilog debug expert. Output ONLY JSON.
User:
Error lines:
{error_snippet_max_10_lines}

Module: {module_name}, Interface: {interface_type}
Known past fixes for this module: {fixes_log_match}

Output format:
{
  "root_cause": "one sentence",
  "error_type": "compile | elaboration | runtime | timeout | protocol",
  "fix_location": "line N or signal name",
  "fix_code": "corrected Verilog snippet",
  "confidence": 1-10,
  "edge_cases": ["what else might break"]
}

## Mistral Validation Prompt
System: Validate this Verilog fix. Be brief.
User:
Original error: {error_type}
Proposed fix: {fix_code}
Is this fix RTL-correct for Vivado xsim? Reply: {"valid": bool, "reason": "string"}

## After Fix Applied
Append to memory/fixes.log:
{date} | {module} | {root_cause} | {fix_summary} | confidence:{score}

## Retry Logic
- Max 3 debug cycles before flagging to human
- On 3rd failure: write detailed report to outputs/reports/debug_escalation.md

## Common Gotchas
- Vivado xvlog: undriven signal → add `assign signal = 0;`
- FAIL on cycle 1: reset not applied before stimulus
- Mismatched widths: Vivado is strict, widths must match exactly
- Back-pressure deadlock: master/slave READY/VALID never both high
- Clock not initialized: must set `clk = 0` in initial block

## Token Budget
- Error snippet: ~150 tokens
- Module context: ~100 tokens
- Generated fix: ~300 tokens
- Review: ~150 tokens
- Total: ~700 tokens per cycle
