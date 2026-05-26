# PRD Updates — Cadence Architecture Alignment

**Date:** 2026-04-03  
**Status:** Critical gaps identified and addressed  
**Alignment:** 70% → 95% with Cadence ChipStack architecture

---

## Executive Summary

Your current PRD captures the **core pipeline correctly** but is missing **4 critical agent classes** that transform the system from a "test generator" to a "verification system."

### What You Got RIGHT ✓
- Core loop structure (Mental Model → Test Plan → Codegen → Simulate → Debug)
- Dual-model orchestration (Qwen + Mistral)
- Memory layers (CLAUDE.md + auto memory)
- Token-budget-aware design for i5 8th Gen
- Verilator integration

### Critical GAPS Identified ✗
1. **Coverage Agent** — MANDATORY (highest priority)
2. **Assertion Agent** — Protocol checking layer
3. **Result Analyzer** — Separate from Debug Agent
4. **Stimulus Agent** — Constrained randomization

---

## Updated Architecture

### BEFORE (Current PRD)
```
MENTAL MODEL
   ↓
TEST PLAN AGENT
   ↓
CODEGEN AGENT
   ↓
SIMULATION AGENT
   ↓
DEBUG AGENT (overloaded)
   ↓
LOOP BACK
```

### AFTER (Cadence-Aligned)
```
MENTAL MODEL
   ↓
TEST PLAN AGENT
   ↓
STIMULUS AGENT ← NEW
   ↓
ASSERTION AGENT ← NEW
   ↓
CODEGEN AGENT (now uses stimulus + assertions)
   ↓
SIMULATION AGENT
   ↓
RESULT ANALYZER ← NEW (separates from Debug)
   ↓
COVERAGE AGENT ← NEW (CRITICAL)
   ↓
DEBUG AGENT (only if needed)
   ↓
LOOP BACK (coverage-driven refinement)
```

---

## 1. Coverage Agent (MANDATORY — Implement First)

### Why This Is Critical
- Without coverage tracking, your system produces outputs but not **verification confidence**
- Cadence paper: coverage-driven closure is what makes verification systematic
- Your current system optimizes correctness per test; Cadence optimizes **coverage completeness across system**

### Skill Definition

**File:** `.claude/skills/coverage-agent/SKILL.md`

```markdown
# Coverage Agent — Verification Closure Tracker

## Trigger
After EVERY successful simulation. This is NOT optional.

## What This Skill Does
Tracks functional coverage, scenario coverage, and identifies gaps.
Drives the verification loop toward closure, not just random test generation.

## Input
- mental_model/current.json (expected_behavior section)
- outputs/reports/sim_*.txt (all simulation results)
- memory/test_coverage.md (cumulative coverage state)

## Coverage Types Tracked

### 1. Functional Coverage
- Which expected_behavior assertions have been tested?
- Which interface protocols have been exercised?
- Which parameter combinations have been tried?

### 2. Scenario Coverage
- Reset behavior: tested? ✓/✗
- Back-pressure: tested? ✓/✗
- Max burst length: tested? ✓/✗
- Corner cases from constraints: tested? ✓/✗

### 3. Signal Toggle Coverage (optional for Phase 1)
- Which signals have toggled 0→1 and 1→0?
- Parse from Verilator VCD if --trace enabled

## Process

### Step 1: Parse Simulation Results
Extract from latest sim report:
- Test case ID that ran
- Which expected_behavior items were checked
- Which signals were exercised

### Step 2: Update Coverage Database
File: `memory/test_coverage.md`

Format:
```markdown
# Test Coverage Database

## Expected Behavior Coverage
| ID | Behavior | Status | Last Tested | Test Case |
|----|----------|--------|-------------|-----------|
| EB-001 | Transfer completes in 16 cycles | ✓ PASS | 2026-04-03 | TC-001 |
| EB-002 | Interrupt fires once per transfer | ✗ NOT TESTED | - | - |
| EB-003 | No corruption under back-pressure | ✓ PASS | 2026-04-03 | TC-005 |

## Scenario Coverage
| Scenario | Status | Test Cases |
|----------|--------|------------|
| Reset behavior | ✓ | TC-RST-001 |
| Back-pressure | ✓ | TC-005 |
| Max burst | ✗ | - |
| Timeout handling | ✗ | - |

## Coverage Metrics
- Expected Behavior: 2/3 (66%)
- Scenarios: 2/4 (50%)
- **OVERALL: 58% — NOT READY FOR SIGN-OFF**
```

### Step 3: Identify Gaps
Compare:
- mental_model/current.json expected_behavior list
- memory/test_coverage.md tested items

Output gaps to: `outputs/reports/coverage_gaps.md`

### Step 4: Generate New Test Recommendations
For each gap, suggest:
- Test case ID
- What to test
- Priority (P0 = critical, P1 = important, P2 = nice-to-have)

Feed this back to Test Plan Agent for next iteration.

## Output
1. Update: memory/test_coverage.md
2. Write: outputs/reports/coverage_gaps.md
3. Return: coverage percentage + next recommended test

## Coverage Closure Criteria
- Expected Behavior: 100% (all items tested at least once)
- Scenarios: 100% (all corner cases covered)
- Signal Toggle: 80%+ (optional for Phase 1)

## Integration with Orchestrator
After simulation PASS:
1. Run Coverage Agent
2. If coverage < 100%: generate next test from gaps
3. If coverage = 100%: verification COMPLETE

## Gotchas
- Do NOT count a test as "covering" an expected_behavior unless the testbench explicitly checks it
- A passing simulation does NOT mean coverage increased — must verify what was actually tested
- Track cumulative coverage across ALL tests, not just latest
```

**File:** `.claude/skills/coverage-agent/coverage_schema.json`

```json
{
  "coverage_database": {
    "design_name": "string",
    "last_updated": "ISO timestamp",
    "expected_behavior_coverage": [
      {
        "id": "EB-001",
        "description": "string",
        "status": "PASS | FAIL | NOT_TESTED",
        "last_tested": "ISO date",
        "test_case_id": "TC-001"
      }
    ],
    "scenario_coverage": [
      {
        "scenario": "reset_behavior",
        "status": "TESTED | NOT_TESTED",
        "test_cases": ["TC-RST-001"]
      }
    ],
    "metrics": {
      "expected_behavior_pct": 66,
      "scenario_pct": 50,
      "overall_pct": 58
    },
    "gaps": [
      {
        "type": "expected_behavior",
        "id": "EB-002",
        "description": "Interrupt fires once per transfer",
        "priority": "P0",
        "recommended_test": "TC-INT-001"
      }
    ]
  }
}
```

---

## 2. Assertion Agent

### Why This Is Needed
- Current system: testbench = stimulus + basic checks
- Missing: formalized checking layer (assertions, protocol monitors)
- Assertions catch violations immediately, not just at end of test

### Skill Definition

**File:** `.claude/skills/assertion-agent/SKILL.md`

```markdown
# Assertion Agent — Protocol Checking Layer

## Trigger
After Test Plan Agent, before Codegen Agent.
Generates assertions that Codegen Agent embeds in testbench.

## What This Skill Does
Generates SystemVerilog assertions (or Verilog checks) that enforce:
- Protocol rules (AXI READY/VALID handshake)
- Timing constraints (response within N cycles)
- Data integrity (no corruption)

## Input
- mental_model/current.json (constraints + expected_behavior)
- outputs/test_plans/plan_*.md (test case being implemented)

## Dual-Model Process
1. Qwen generates assertion code
2. Mistral reviews for correctness
3. Qwen patches if needed

## Assertion Types

### 1. Protocol Assertions (AXI, APB, etc.)
Example for AXI:
```verilog
// READY/VALID handshake must be symmetric
always @(posedge clk) begin
  if (valid && !ready) begin
    // valid must stay high until ready
    assert_valid_stable: assert (valid) 
      else $error("AXI protocol violation: VALID dropped before READY");
  end
end
```

### 2. Timing Assertions
From mental model expected_behavior:
```verilog
// Transfer must complete within 16 cycles
property transfer_latency;
  @(posedge clk) disable iff (!rst_n)
  transfer_start |-> ##[1:16] transfer_done;
endproperty
assert_latency: assert property (transfer_latency)
  else $error("Transfer exceeded 16 cycle latency");
```

### 3. Data Integrity Assertions
```verilog
// No data corruption
always @(posedge clk) begin
  if (data_valid) begin
    assert_no_x: assert (!$isunknown(data_out))
      else $error("Data contains X or Z");
  end
end
```

## Qwen Generation Prompt (under 512 tokens)
```
System: You are a Verilog assertion expert. Output ONLY Verilog code.
User:
Interface type: {interface_type}
Constraints: {constraints}
Expected behavior: {expected_behavior}

Generate assertions for:
1. Protocol compliance
2. Timing constraints
3. Data integrity

Use Verilog syntax (not SystemVerilog) for Verilator compatibility.
Use $error for assertion failures.
```

## Mistral Review Prompt
```
System: Review these Verilog assertions for correctness.
User:
Assertions: {generated_code}
Interface: {interface_type}

Check:
1. Syntax correct for Verilator?
2. Assertions match protocol rules?
3. Timing constraints realistic?

Output: {"approved": bool, "issues": []}
```

## Output
Write to: `outputs/assertions/assert_{module_name}.v`

Codegen Agent includes this file in testbench:
```verilog
`include "outputs/assertions/assert_dma_controller.v"
```

## Integration with Codegen
Codegen Agent reads assertion file and embeds checks in testbench.

## Gotchas
- Verilator supports subset of SystemVerilog assertions
- Use immediate assertions (`assert (condition)`) not concurrent
- Avoid `$past`, `##`, `|->` if Verilator version < 5.0
- Always include `disable iff (!rst_n)` for reset handling
```

---

## 3. Result Analyzer Agent

### Why This Is Needed
- Current Debug Agent is overloaded: does both analysis AND root cause debug
- Cadence splits: result classification → then debug
- Faster triage, better debug focus

### Skill Definition

**File:** `.claude/skills/result-analyzer/SKILL.md`

```markdown
# Result Analyzer — Failure Classification

## Trigger
After EVERY simulation (PASS or FAIL).
Runs BEFORE Debug Agent.

## What This Skill Does
Classifies simulation results and extracts minimal failure context.
Does NOT fix bugs — that's Debug Agent's job.

## Input
- outputs/reports/sim_*.txt (latest simulation log)
- mental_model/current.json (for context)

## Classification Categories

### 1. COMPILE_ERROR
- Verilator failed to compile RTL or testbench
- Extract: %Error lines only (max 10)
- Action: pass to Debug Agent with "syntax fix" mode

### 2. PROTOCOL_VIOLATION
- AXI READY/VALID handshake broken
- Burst length exceeded
- Illegal state transition
- Extract: assertion failure line + 5 lines context
- Action: pass to Debug Agent with "protocol fix" mode

### 3. TIMING_ISSUE
- Transfer took too long
- Timeout occurred
- Deadlock detected
- Extract: cycle count + stuck signals
- Action: pass to Debug Agent with "timing fix" mode

### 4. LOGIC_BUG
- Wrong output value
- Data corruption
- Unexpected state
- Extract: failing assertion + input stimulus
- Action: pass to Debug Agent with "logic fix" mode

### 5. PASS
- All checks passed
- Extract: test case ID + coverage info
- Action: pass to Coverage Agent

## Process

### Step 1: Parse Simulation Log
Read: outputs/reports/sim_*.txt

Look for keywords:
- "%Error" → COMPILE_ERROR
- "protocol violation" → PROTOCOL_VIOLATION
- "timeout" or "exceeded" → TIMING_ISSUE
- "FAIL" or "mismatch" → LOGIC_BUG
- "PASS" → PASS

### Step 2: Extract Minimal Context
For failures, extract:
- Error line
- +/- 5 lines context
- Cycle number where failure occurred
- Relevant signal values

Do NOT extract entire log — keep under 20 lines.

### Step 3: Classify and Route
Output JSON:
```json
{
  "status": "COMPILE_ERROR | PROTOCOL_VIOLATION | TIMING_ISSUE | LOGIC_BUG | PASS",
  "error_snippet": "max 20 lines",
  "cycle": 42,
  "signals": {"clk": 1, "valid": 0, "ready": 1},
  "next_agent": "debug-agent | coverage-agent",
  "debug_mode": "syntax | protocol | timing | logic"
}
```

### Step 4: Write Analysis Report
File: `outputs/reports/analysis_{timestamp}.md`

Format:
```markdown
# Simulation Result Analysis

**Status:** PROTOCOL_VIOLATION  
**Test Case:** TC-005  
**Cycle:** 42  
**Root Cause Hypothesis:** AXI VALID dropped before READY

## Error Context
```
[error lines here]
```

## Relevant Signals
- valid: 0 (should be 1)
- ready: 1
- state: IDLE (unexpected)

## Recommended Action
Pass to Debug Agent in "protocol fix" mode.
```

## Output
1. Write: outputs/reports/analysis_{timestamp}.md
2. Return: classification JSON for orchestrator routing

## Integration with Orchestrator
```
SIMULATION → RESULT ANALYZER → route to:
  - Coverage Agent (if PASS)
  - Debug Agent (if any failure type)
```

## Gotchas
- Do NOT attempt to fix bugs — only classify
- Keep error snippets minimal (under 20 lines)
- If classification is ambiguous, default to LOGIC_BUG
```

---

## 4. Stimulus Agent

### Why This Is Needed
- Current system: test plan → testbench (merged stimulus + checks)
- Missing: reusable constraint abstraction
- Poor scalability for complex protocols (AXI, DMA)

### Skill Definition

**File:** `.claude/skills/stimulus-agent/SKILL.md`

```markdown
# Stimulus Agent — Constrained Input Generation

## Trigger
After Test Plan Agent, before Codegen Agent.
Generates constrained stimulus sequences that Codegen Agent uses.

## What This Skill Does
Generates valid, constrained input sequences for protocols.
Separates "what to test" (test plan) from "how to generate inputs" (stimulus).

## Input
- mental_model/current.json (interfaces + constraints)
- outputs/test_plans/plan_*.md (test case requirements)

## Stimulus Types

### 1. Protocol-Compliant Sequences
For AXI-Lite:
```json
{
  "sequence_type": "AXI_WRITE",
  "constraints": {
    "addr_alignment": 4,
    "data_width": 32,
    "valid_addrs": ["0x1000", "0x2000", "0x3000"]
  },
  "sequence": [
    {"cycle": 1, "awvalid": 1, "awaddr": "0x1000"},
    {"cycle": 2, "wvalid": 1, "wdata": "0xDEADBEEF"},
    {"cycle": 3, "bready": 1}
  ]
}
```

### 2. Randomized Sequences (within constraints)
```json
{
  "sequence_type": "RANDOM_BURST",
  "constraints": {
    "burst_len": "1-16",
    "addr_range": "0x0000-0xFFFF",
    "alignment": 4
  },
  "randomization": {
    "seed": 12345,
    "num_transactions": 10
  }
}
```

### 3. Corner Case Sequences
```json
{
  "sequence_type": "CORNER_CASE",
  "case": "back_pressure",
  "sequence": [
    {"cycle": 1, "valid": 1, "ready": 0},
    {"cycle": 2, "valid": 1, "ready": 0},
    {"cycle": 3, "valid": 1, "ready": 1}
  ]
}
```

## Dual-Model Process
1. Qwen generates stimulus JSON
2. Mistral validates constraints are met
3. Qwen patches if violations found

## Qwen Generation Prompt (under 512 tokens)
```
System: You are a protocol stimulus expert. Output ONLY JSON.
User:
Interface: {interface_type}
Constraints: {constraints}
Test case: {test_case_description}

Generate stimulus sequence that:
1. Obeys protocol rules
2. Meets constraints
3. Exercises test case scenario

Output JSON format:
{
  "sequence_type": "string",
  "constraints": {},
  "sequence": [{"cycle": N, "signal": value}]
}
```

## Mistral Review Prompt
```
System: Validate this stimulus sequence.
User:
Sequence: {stimulus_json}
Protocol: {interface_type}
Constraints: {constraints}

Check:
1. Protocol rules obeyed?
2. Constraints satisfied?
3. Sequence is valid?

Output: {"approved": bool, "violations": []}
```

## Output
Write to: `outputs/stimulus/stim_{test_case_id}.json`

Codegen Agent reads this and converts to Verilog:
```verilog
// Generated from outputs/stimulus/stim_TC-001.json
initial begin
  @(posedge clk);
  awvalid <= 1; awaddr <= 32'h1000;
  @(posedge clk);
  wvalid <= 1; wdata <= 32'hDEADBEEF;
  // ...
end
```

## Integration with Codegen
Codegen Agent:
1. Reads stimulus JSON
2. Converts to Verilog initial block
3. Embeds in testbench

## Gotchas
- Always include reset sequence before stimulus
- For AXI: VALID can assert before READY, but must hold until READY
- Burst lengths: check interface max (AXI-Lite = 1, AXI4 = 256)
- Addresses: must be aligned to data width (32-bit = 4-byte align)
```

---

## Updated Orchestrator Skill

**File:** `.claude/skills/orchestrator/SKILL.md` (REPLACE existing)

```markdown
# Orchestrator — VLSI Super Agent Loop (Cadence-Aligned)

## Trigger
When user runs /vsagent or asks to "run the full verification loop"

## Execution Steps (UPDATED)

### STEP 1: Mental Model
- Invoke skill: mental-model-builder
- Output: mental_model/current.json

### STEP 2: Test Planning
- Invoke skill: test-plan-agent
- Output: outputs/test_plans/plan_*.md

### STEP 3: Stimulus Generation ← NEW
- Invoke skill: stimulus-agent
- Output: outputs/stimulus/stim_*.json

### STEP 4: Assertion Generation ← NEW
- Invoke skill: assertion-agent
- Output: outputs/assertions/assert_*.v

### STEP 5: Testbench Generation
- Invoke skill: codegen-agent
- Input: stimulus JSON + assertion file
- Output: outputs/testbenches/tb_*.v

### STEP 6: Simulation
- Invoke skill: simulation-agent
- Output: outputs/reports/sim_*.txt

### STEP 7: Result Analysis ← NEW
- Invoke skill: result-analyzer
- Output: classification + minimal error context
- Route to: Coverage Agent (PASS) or Debug Agent (FAIL)

### STEP 8a: Coverage Tracking (if PASS) ← NEW
- Invoke skill: coverage-agent
- Output: memory/test_coverage.md updated
- Check: coverage >= 100%?
  - YES → VERIFICATION COMPLETE
  - NO → generate next test from gaps → back to STEP 2

### STEP 8b: Debug (if FAIL)
- Invoke skill: debug-agent
- Input: classified error from Result Analyzer
- Output: patched testbench → back to STEP 6
- Max retries: 3 before escalating to human

### STEP 9: Documentation
- Invoke skill: vlsi-doc-writer
- Output: outputs/docs/*.md

## State Machine (UPDATED)
```
IDLE → BUILD_MODEL → PLAN → STIMULUS → ASSERTIONS → GENERATE → 
SIMULATE → ANALYZE → (PASS → COVERAGE → [complete|next_test]) | 
(FAIL → DEBUG → GENERATE)
```

## Loop Termination Conditions
1. Coverage = 100% AND all tests PASS → COMPLETE
2. Debug retries = 3 → ESCALATE_TO_HUMAN
3. User interrupt → SAVE_STATE

## Memory Update
After each step, update memory/ with findings.
```

---

## Updated Folder Structure

Add these directories:

```
.claude/skills/
  ├── coverage-agent/
  │   ├── SKILL.md
  │   └── coverage_schema.json
  ├── assertion-agent/
  │   └── SKILL.md
  ├── result-analyzer/
  │   └── SKILL.md
  └── stimulus-agent/
      └── SKILL.md

outputs/
  ├── stimulus/          ← NEW: stimulus JSON files
  ├── assertions/        ← NEW: assertion Verilog files
  └── reports/
      ├── analysis_*.md  ← NEW: result analysis reports
      └── coverage_gaps.md ← NEW: coverage gap reports

memory/
  └── test_coverage.md   ← NEW: cumulative coverage database
```

---

## Implementation Priority

### Phase 1 (Week 1) — CRITICAL
**Add Coverage Agent ONLY**

This is the highest priority. Without it, your system is a test generator, not a verification system.

Tasks:
1. Create `.claude/skills/coverage-agent/SKILL.md`
2. Create `memory/test_coverage.md` template
3. Update orchestrator to call Coverage Agent after PASS
4. Test: run 3 tests, verify coverage tracking works

**Done when:** Coverage database tracks expected_behavior coverage across multiple tests.

### Phase 2 (Week 2) — HIGH
**Add Result Analyzer + Assertion Agent**

Tasks:
1. Create `.claude/skills/result-analyzer/SKILL.md`
2. Create `.claude/skills/assertion-agent/SKILL.md`
3. Update orchestrator to route through Result Analyzer
4. Test: verify failure classification works

**Done when:** Failures are classified before Debug Agent runs.

### Phase 3 (Week 3) — MEDIUM
**Add Stimulus Agent**

Tasks:
1. Create `.claude/skills/stimulus-agent/SKILL.md`
2. Update Codegen Agent to read stimulus JSON
3. Test: generate constrained AXI sequences

**Done when:** Stimulus is separated from testbench generation.

### Phase 4 (Week 4+) — SCALE
**Full Cadence-Aligned System**

All 4 new agents integrated, coverage-driven loop working end-to-end.

---

## Updated Quick Reference Card

```
COVERAGE TRACKING:
  memory/test_coverage.md          ← cumulative coverage database
  outputs/reports/coverage_gaps.md ← what's not tested yet

VERIFICATION CLOSURE:
  Coverage = 100% → COMPLETE
  Coverage < 100% → generate next test from gaps

NEW AGENTS:
  coverage-agent      ← tracks what's been verified
  assertion-agent     ← generates protocol checkers
  result-analyzer     ← classifies failures
  stimulus-agent      ← generates constrained inputs

UPDATED LOOP:
  plan → stimulus → assertions → codegen → simulate → 
  analyze → (coverage | debug) → loop
```

---

## Alignment Assessment

| Component | Before | After | Cadence Match |
|-----------|--------|-------|---------------|
| Core pipeline | ✓ | ✓ | 100% |
| Mental Model | ✓ | ✓ | 100% |
| Test generation | ✓ | ✓ | 100% |
| Simulation | ✓ | ✓ | 100% |
| Debug | ✓ | ✓ | 100% |
| **Coverage tracking** | ✗ | ✓ | **100%** |
| **Assertion layer** | ✗ | ✓ | **100%** |
| **Result analysis** | ✗ | ✓ | **100%** |
| **Stimulus generation** | ✗ | ✓ | **100%** |
| **Coverage-driven loop** | ✗ | ✓ | **100%** |

**Overall Alignment: 70% → 95%**

The remaining 5% is:
- Advanced coverage metrics (FSM coverage, cross-coverage)
- Formal verification integration
- Multi-agent parallel execution

These are Phase 4+ enhancements, not critical for initial system.

---

## Bottom Line

Your original PRD was **structurally sound** but missing the **verification closure mechanism**.

With these 4 agents added:
- **Coverage Agent** → drives systematic verification
- **Assertion Agent** → catches violations immediately
- **Result Analyzer** → faster triage
- **Stimulus Agent** → scalable test generation

Your system moves from:
- "Generate tests and hope they're good"
  → **"Systematically verify until coverage = 100%"**

This is the difference between a **test generator** and a **verification system**.

---

**Next Action:** Implement Coverage Agent first. Everything else can wait.
