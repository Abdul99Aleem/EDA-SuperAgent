# VLSI Super Agent — Complete PRD
**Version:** 1.0  
**Author:** Aleem (adapted from Cadence ChipStack AI Super Agent architecture)  
**Hardware:** i5 8th Gen · 8GB RAM · No GPU  
**Primary Model:** Qwen2.5-Coder:7b-instruct-q4_K_M (via Ollama)  
**Review Model:** Mistral:7b-instruct-q4_K_M (via Ollama)  
**Platform:** Claude Code (terminal agent)  
**Target:** RTL verification, testbench generation, VLSI learning docs

---

## Table of Contents

1. [What You Are Building](#1-what-you-are-building)
2. [System Architecture](#2-system-architecture)
3. [Memory Strategy — No RAG, No Obsidian](#3-memory-strategy)
4. [Claude Code Setup — Complete](#4-claude-code-setup)
5. [Folder Structure](#5-folder-structure)
6. [CLAUDE.md — Root (The Brain)](#6-claudemd-root)
7. [Skills — Every Agent](#7-skills)
8. [Hooks](#8-hooks)
9. [Slash Commands](#9-slash-commands)
10. [Dual-Model Orchestration](#10-dual-model-orchestration)
11. [Mental Model Schema](#11-mental-model-schema)
12. [Agent Prompt Templates](#12-agent-prompt-templates)
13. [Execution Loop](#13-execution-loop)
14. [VLSI Doc Writer (Learning Layer)](#14-vlsi-doc-writer)
15. [Build Phases](#15-build-phases)
16. [RAM Budget](#16-ram-budget)
17. [First Session Script](#17-first-session-script)

---

## 1. What You Are Building

A local, offline-capable, Claude Code-powered agentic system that mirrors
the Cadence ChipStack AI Super Agent architecture at your hardware level.

**From the Cadence PDF (your reference):**

```
PROMPT
  ↓
MENTAL MODEL ← Ground truth of chip intent (RTL + spec → JSON)
  ↓
SUPER AGENT (orchestrator) ← Claude Code is this
  ↓
SPECIALIZED AGENTS
  ├── Test Plan Agent    → what to test
  ├── Code Gen Agent     → writes testbench Verilog
  ├── Simulation Agent   → runs Verilator
  └── Debug Agent        → analyzes failures
  ↓
EDA TOOL (Verilator)
  ↓
OUTPUTS: testbenches, reports, VLSI learning docs
```

**What the PDF proved matters most:**
- Mental Model raised test correctness from 42% (RAG) to 83% — this is your #1 priority
- The loop is closed and iterative — not one-shot generation
- Human stays in the loop — you validate, agents suggest
- Custom LLMs gave 20% improvement on test plan generation — your structured prompts compensate for this

**Your system adds:**
- Dual-model review loop: Qwen generates → Mistral reviews → Qwen patches
- Native Claude Code memory (no Obsidian, no RAG)
- VLSI teaching doc generator that explains what just happened in your RTL

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLAUDE CODE SESSION                       │
│                                                                  │
│  CLAUDE.md (loaded every session → permanent brain)             │
│  auto memory (MEMORY.md → Claude writes itself)                 │
│  .claude/rules/ (per-domain rules → lazy loaded)                │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   SUPER AGENT LOOP                       │   │
│  │                                                          │   │
│  │  /vsagent → triggers orchestrator skill                  │   │
│  │                                                          │   │
│  │  STEP 1: Build Mental Model                              │   │
│  │    skill: mental-model-builder                           │   │
│  │    input: inputs/rtl/*.v + inputs/specs/*.txt            │   │
│  │    output: mental_model/current.json                     │   │
│  │                                                          │   │
│  │  STEP 2: Plan Tests                                      │   │
│  │    skill: test-plan-agent                                │   │
│  │    model: Qwen2.5-Coder (primary)                        │   │
│  │    review: Mistral (secondary)                           │   │
│  │    output: outputs/test_plans/plan.md                    │   │
│  │                                                          │   │
│  │  STEP 3: Generate Testbench                              │   │
│  │    skill: codegen-agent                                  │   │
│  │    model: Qwen2.5-Coder                                  │   │
│  │    review: Mistral                                       │   │
│  │    output: outputs/testbenches/*.v                       │   │
│  │                                                          │   │
│  │  STEP 4: Run Simulation                                  │   │
│  │    skill: simulation-agent                               │   │
│  │    tool: Verilator (subprocess)                          │   │
│  │    output: outputs/reports/sim_result.txt                │   │
│  │                                                          │   │
│  │  STEP 5: Debug (if FAIL)                                 │   │
│  │    skill: debug-agent                                    │   │
│  │    model: Qwen2.5-Coder                                  │   │
│  │    review: Mistral                                       │   │
│  │    output: patch → back to STEP 3                        │   │
│  │                                                          │   │
│  │  STEP 6: Write VLSI Doc                                  │   │
│  │    skill: vlsi-doc-writer                                │   │
│  │    output: outputs/docs/[topic].md                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  MEMORY LAYER                                                    │
│  ├── CLAUDE.md → permanent project truth                        │
│  ├── MEMORY.md → auto-written by Claude per session            │
│  ├── memory/debugging.md → past failures + fixes               │
│  ├── memory/mental_model_log.md → model evolution log          │
│  └── memory/vlsi_concepts.md → learned concepts index          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Memory Strategy

**No Obsidian. No RAG. No vector DB. Pure Claude Code native.**

This is the correct approach for your setup. Here is exactly how Claude Code
memory works and how to exploit every layer:

### Layer 1: CLAUDE.md (You Write — Permanent Brain)

Loaded at the START of every session. This is your ground truth.

```
CLAUDE.md                     ← root project truth (under 200 lines)
.claude/rules/
  ├── vlsi-conventions.md     ← Verilog style rules
  ├── agent-workflow.md       ← how agents should behave
  ├── simulation.md           ← Verilator conventions
  └── review-protocol.md     ← dual-model review rules
```

**Key insight:** Rules in `.claude/rules/` are path-scoped and lazy-loaded.
Only load into context when you're working on matching files. This keeps
your context window clean.

### Layer 2: Auto Memory (Claude Writes — Session Learning)

Claude Code (v2.1.59+) automatically writes what it learns to:
```
~/.claude/projects/<project>/memory/
  ├── MEMORY.md              ← index, first 200 lines loaded every session
  ├── debugging.md           ← patterns Claude found in your RTL failures
  ├── mental_model_log.md    ← how your chip's mental model evolved
  └── vlsi_concepts.md       ← VLSI terms Claude taught you this session
```

**Enable Auto Dream** (memory consolidation between sessions):
Run `/memory` in Claude Code → toggle "Auto-dream: on"
This is like REM sleep — Claude prunes stale notes, merges contradictions,
converts "yesterday" to absolute dates. Critical for long projects.

### Layer 3: Project Memory Files (You Curate — Structured Knowledge)

```
memory/
  ├── fixes.log              ← every bug fixed with root cause
  ├── decisions.log          ← architectural decisions + why
  ├── mental_model/
  │   ├── current.json       ← active mental model
  │   └── history/           ← versioned mental models per RTL iteration
  └── test_coverage.md       ← what's been tested, what's not
```

### Layer 4: Byterover MCP (Optional — Shared Memory Across Tools)

Byterover is a file-based memory layer with 92.2% retrieval accuracy and
Git-like version control. Use it if you want your mental model and debug
history to be searchable across Claude Code sessions without loading
everything into context.

Install:
```bash
# Add to your Claude Code MCP config
# byterover-mcp → stores/retrieves design knowledge by semantic search
```

For now, the native Claude Code memory is sufficient. Add Byterover in Phase 3.

### What Karpathy Said (Applied to Your System)

Karpathy noted that Claude Code runs on your computer with your private
environment, data and context — and that the intelligence part has outpaced
tool integration. Your job is to solve the integration side: structured
CLAUDE.md + auto memory IS the integration. You are building the
"organizational workflow" Karpathy said the industry needs to metabolize.

---

## 4. Claude Code Setup — Complete

### Step 0: Prerequisites

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Verify version (need 2.1.59+ for auto memory)
claude --version

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull both models (do this first, takes time)
ollama pull qwen2.5-coder:7b-instruct-q4_K_M
ollama pull mistral:7b-instruct-q4_K_M

# Install Verilator
sudo apt install verilator

# Verify
verilator --version
ollama list
```

### Step 1: Create Project

```bash
mkdir vlsi-super-agent
cd vlsi-super-agent
git init

# Create all directories
mkdir -p .claude/skills/mental-model-builder
mkdir -p .claude/skills/test-plan-agent
mkdir -p .claude/skills/codegen-agent
mkdir -p .claude/skills/simulation-agent
mkdir -p .claude/skills/debug-agent
mkdir -p .claude/skills/vlsi-doc-writer
mkdir -p .claude/skills/orchestrator
mkdir -p .claude/rules
mkdir -p .claude/commands
mkdir -p .claude/hooks
mkdir -p inputs/rtl
mkdir -p inputs/specs
mkdir -p mental_model/history
mkdir -p outputs/testbenches
mkdir -p outputs/reports
mkdir -p outputs/docs
mkdir -p outputs/test_plans
mkdir -p memory
mkdir -p tools
```

### Step 2: Settings File

Create `.claude/settings.json`:

```json
{
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "./memory",
  "model": "claude-sonnet-4-5",
  "permissions": {
    "allow": [
      "Bash(verilator:*)",
      "Bash(ollama:*)",
      "Bash(python3:*)",
      "Read(**)",
      "Write(outputs/**)",
      "Write(memory/**)",
      "Write(mental_model/**)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(sudo:*)"
    ]
  }
}
```

### Step 3: Launch Claude Code

```bash
# From project root — always launch from here
claude

# First command in every session:
# /memory   ← check what was remembered from last session
```

---

## 5. Folder Structure

```
vlsi-super-agent/
│
├── CLAUDE.md                          ← THE BRAIN (you write this)
├── CLAUDE.local.md                    ← personal prefs (gitignored)
│
├── .claude/
│   ├── settings.json                  ← permissions + model config
│   ├── rules/
│   │   ├── vlsi-conventions.md        ← Verilog style (path-scoped)
│   │   ├── agent-workflow.md          ← agent behavior rules
│   │   ├── simulation.md             ← Verilator rules
│   │   └── review-protocol.md        ← dual-model review rules
│   │
│   ├── skills/
│   │   ├── orchestrator/
│   │   │   └── SKILL.md              ← super agent loop
│   │   ├── mental-model-builder/
│   │   │   ├── SKILL.md
│   │   │   └── schema.json           ← mental model template
│   │   ├── test-plan-agent/
│   │   │   └── SKILL.md
│   │   ├── codegen-agent/
│   │   │   └── SKILL.md
│   │   ├── simulation-agent/
│   │   │   └── SKILL.md
│   │   ├── debug-agent/
│   │   │   ├── SKILL.md
│   │   │   └── gotchas.md            ← common RTL failure patterns
│   │   └── vlsi-doc-writer/
│   │       ├── SKILL.md
│   │       └── templates/
│   │           └── concept.md        ← doc template
│   │
│   ├── commands/
│   │   ├── vsagent.md                ← /vsagent → runs full loop
│   │   ├── build-mental-model.md     ← /build-mental-model
│   │   ├── run-sim.md                ← /run-sim
│   │   ├── debug-last.md             ← /debug-last
│   │   └── teach-me.md              ← /teach-me [topic]
│   │
│   └── hooks/
│       ├── post-tool-use.sh          ← writes to memory after tool use
│       └── session-start.sh          ← loads context on session start
│
├── inputs/
│   ├── rtl/                          ← your .v files go here
│   └── specs/                        ← plain English design specs
│
├── mental_model/
│   ├── current.json                  ← active mental model
│   └── history/                      ← versioned snapshots
│
├── memory/                           ← Claude writes here automatically
│   ├── MEMORY.md                     ← auto index (200 lines max)
│   ├── debugging.md                  ← failure patterns + fixes
│   ├── mental_model_log.md           ← model evolution
│   ├── vlsi_concepts.md              ← concepts learned this project
│   ├── fixes.log                     ← every fix with root cause
│   └── decisions.log                 ← architectural decisions
│
├── outputs/
│   ├── testbenches/                  ← generated .v testbenches
│   ├── reports/                      ← simulation logs
│   ├── test_plans/                   ← generated test plans
│   └── docs/                         ← VLSI teaching documents
│
└── tools/
    ├── run_verilator.sh              ← Verilator wrapper script
    ├── parse_rtl.py                  ← RTL parser (extracts ports)
    └── ollama_client.py              ← Ollama API wrapper
```

---

## 6. CLAUDE.md — Root (The Brain)

Create this file at project root. This is loaded EVERY session.
Keep it UNDER 200 lines.

```markdown
# VLSI Super Agent — Project Brain

## What This Project Is
An agentic RTL verification system modeled on Cadence ChipStack AI Super Agent.
Primary goal: closed-loop testbench generation + simulation + debug for VLSI RTL.
Secondary goal: generate VLSI learning documentation grounded in actual RTL.

## Hardware Constraints
- i5 8th Gen CPU, 8GB RAM, no GPU
- Models run via Ollama (localhost:11434)
- Primary: qwen2.5-coder:7b-instruct-q4_K_M (generation)
- Review:  mistral:7b-instruct-q4_K_M (validation)
- Keep ALL prompts under 2048 tokens. Pass snippets, not full files.

## Current RTL Under Verification
- Design: [UPDATE THIS — e.g., AXI DMA Subsystem]
- RTL files: inputs/rtl/
- Spec: inputs/specs/design.txt
- Mental model: mental_model/current.json (ALWAYS read this before any agent task)

## Agent Workflow (ALWAYS follow this order)
1. Read mental_model/current.json
2. Read memory/MEMORY.md (first 200 lines auto-loaded)
3. Check memory/debugging.md for known failure patterns
4. Execute agent task
5. Write result to outputs/
6. Update memory/ with what was learned

## Dual-Model Review Protocol
- Generation model: Qwen2.5-Coder → generates testbench/test plan/debug fix
- Review model: Mistral → reviews output, flags issues
- Format: call Qwen first → pipe output to Mistral review → Qwen patches if needed
- Max 2 review cycles per artifact before escalating to human

## Memory Protocol
ALWAYS check memory before starting any task:
1. mental_model/current.json — chip ground truth
2. memory/MEMORY.md — session learnings index
3. memory/debugging.md — known failure patterns
4. memory/fixes.log — past fixes (search by module name)

After completing any task:
- Write key findings to memory/ (Claude does this automatically via auto memory)
- If fix was found: append to memory/fixes.log with format:
  DATE | MODULE | ROOT_CAUSE | FIX | CONFIDENCE

## Verilator Commands
Run simulation:
  bash tools/run_verilator.sh <rtl_file> <testbench_file>

Parse RTL ports:
  python3 tools/parse_rtl.py inputs/rtl/<file>.v

## Code Conventions
- Verilog only (no SystemVerilog unless RTL uses it)
- Testbenches: outputs/testbenches/tb_<module_name>.v
- Always add // GENERATED BY VLSI-SUPER-AGENT to top of generated files
- Signal names: snake_case, active-low signals end with _n

## Do NOT
- Do not load entire .v files into context. Use parse_rtl.py to extract ports.
- Do not run ollama with models larger than 7B (RAM limit)
- Do not generate testbenches without first reading mental_model/current.json
- Do not commit outputs/ to git (add to .gitignore)

## @imports (loaded on demand)
@.claude/rules/vlsi-conventions.md
@.claude/rules/agent-workflow.md
@.claude/rules/review-protocol.md
```

---

## 7. Skills

Skills are folders in `.claude/skills/`. Each has a `SKILL.md` that tells
Claude when and how to use the skill. They load only when invoked.

### 7.1 Orchestrator Skill

`.claude/skills/orchestrator/SKILL.md`:

```markdown
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
- Tool: bash tools/run_verilator.sh
- Output: outputs/reports/sim_<timestamp>.txt
- Parse: PASS / FAIL + error lines

### STEP 5: Debug (only if FAIL)
- Invoke skill: debug-agent
- Input: error lines (max 10) + mental model context
- Primary model: Qwen2.5-Coder
- Review model: Mistral
- Output: patched testbench → go back to STEP 4
- Max retries: 3 before flagging human

### STEP 6: Documentation
- Invoke skill: vlsi-doc-writer
- Input: what was verified + mental model
- Output: outputs/docs/<topic>_<date>.md

## State Machine
IDLE → BUILD_MODEL → PLAN → GENERATE → SIMULATE → (PASS→DOC | FAIL→DEBUG→GENERATE)

## Memory Update (after every step)
Ask Claude to write findings to memory/ using auto memory.
Specifically: "Remember that [finding] for [module]"
```

---

### 7.2 Mental Model Builder Skill

`.claude/skills/mental-model-builder/SKILL.md`:

```markdown
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

Schema (from schema.json in this skill folder):
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
    "interrupt fires exactly once per transfer",
    "no data corruption under back-pressure"
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
```

---

### 7.3 Test Plan Agent Skill

`.claude/skills/test-plan-agent/SKILL.md`:

```markdown
# Test Plan Agent

## Trigger
When orchestrator invokes after mental model is built.

## Input
- mental_model/current.json (MUST exist)
- memory/debugging.md (check for known failure patterns to include)

## Dual-Model Process
1. Qwen2.5-Coder generates test plan
2. Mistral reviews for completeness and RTL correctness
3. Qwen patches if Mistral flags gaps

## Qwen Prompt Template (keep under 512 tokens)
System: You are a Verilog verification expert. Output ONLY JSON.
User: 
Mental model summary:
- Module: {name}
- Interfaces: {interface_types}
- Key constraints: {constraints[0:3]}
- Expected behavior: {expected_behavior[0:3]}

Generate test cases. Format:
{
  "test_cases": [
    {
      "id": "TC001",
      "name": "string",
      "category": "functional | corner | stress | protocol",
      "inputs": {"signal": "value"},
      "expected_output": {"signal": "value"},
      "pass_criteria": "string",
      "priority": "P0 | P1 | P2"
    }
  ]
}

## Mistral Review Prompt
System: You are a senior RTL verification engineer reviewing a test plan.
User:
Test plan: {test_plan_json}
Mental model constraints: {constraints}
Flag: missing corner cases, protocol violations, unreachable states.
Output JSON: {"approved": bool, "issues": ["list"], "missing_tests": ["list"]}

## Output
Write to: outputs/test_plans/plan_<YYYYMMDD_HHMM>.md
Also update: memory/MEMORY.md with summary of what was planned

## Gotchas
- Always include: reset behavior test (TC-RST-001)
- Always include: back-pressure test for AXI interfaces
- Always include: max burst length test
- P0 tests must run first. Do not skip P0 for coverage.
```

---

### 7.4 Code Gen Agent Skill

`.claude/skills/codegen-agent/SKILL.md`:

```markdown
# Code Gen Agent — Testbench Generator

## Trigger
When orchestrator invokes after test plan exists.

## Input
- mental_model/current.json
- outputs/test_plans/plan_<latest>.md
- memory/debugging.md (avoid past failure patterns)

## Dual-Model Process
1. Qwen2.5-Coder writes Verilog testbench
2. Mistral reviews for syntax, completeness, gotchas
3. Qwen patches based on review

## Qwen Generation Prompt (under 1024 tokens)
System: You are a Verilog testbench expert. Output ONLY valid Verilog code.
User:
Module under test: {module_name}
Ports:
  inputs: {port_list}
  outputs: {port_list}
Interface type: {interface_type}
Test case to implement: {test_case_json}

Write a self-checking Verilog testbench.
Requirements:
- Clock period: 10ns
- Reset: active-low, 5 cycles
- Include $display for pass/fail
- Include $finish
- Use // GENERATED BY VLSI-SUPER-AGENT header

## Mistral Review Prompt
System: You are reviewing Verilog testbench code. Be concise.
User:
Testbench:
{first_50_lines_only}

Check:
1. Clock generation correct?
2. Reset sequence correct?
3. Stimuli match test case intent?
4. Self-checking assertions present?
Output: {"approved": bool, "issues": ["list"], "line_fixes": []}

## Output
Write to: outputs/testbenches/tb_{module_name}_{tc_id}.v

## Gotchas
- Verilator does NOT support: $random, $realtime, fork-join, UVM
- Use `$urandom_range` not `$random` for Verilator compatibility
- All signals must be declared before use (no implicit wires)
- Use non-blocking assignments (<=) in always @(posedge clk) blocks
- Initial blocks: use for reset only, not for test stimuli
```

---

### 7.5 Simulation Agent Skill

`.claude/skills/simulation-agent/SKILL.md`:

```markdown
# Simulation Agent

## Trigger
When orchestrator invokes after testbench exists.

## What This Skill Does
Runs Verilator simulation and parses results. Does NOT use LLM — pure tool execution.

## Execution
```bash
bash tools/run_verilator.sh {rtl_file} {testbench_file}
```

## Parse Output For
- "PASS" → simulation passed
- "FAIL" or "Error" → simulation failed
- "%Error" → Verilator compile error (bad Verilog syntax)
- "Simulation time limit" → infinite loop in testbench

## Result Categories
1. COMPILE_ERROR → go to debug-agent with error lines
2. RUNTIME_FAIL → go to debug-agent with failing assertion lines
3. TIMEOUT → go to debug-agent, likely infinite loop
4. PASS → go to vlsi-doc-writer

## Output
Write to: outputs/reports/sim_{timestamp}.txt
Write summary to: memory/MEMORY.md

## Gotchas
- Verilator requires --cc flag for C++ simulation
- Add --exe sim_main.cpp for standalone binary
- Use --trace for VCD waveform output (optional, uses more RAM)
- If compile fails, paste ONLY the %Error lines to debug agent (not full log)
```

---

### 7.6 Debug Agent Skill

`.claude/skills/debug-agent/SKILL.md`:

```markdown
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
  "error_type": "compile | runtime | timeout | protocol",
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
Is this fix RTL-correct for Verilator? Reply: {"valid": bool, "reason": "string"}

## After Fix Applied
Append to memory/fixes.log:
{date} | {module} | {root_cause} | {fix_summary} | confidence:{score}

## Retry Logic
- Max 3 debug cycles before flagging to human
- On 3rd failure: write detailed report to outputs/reports/debug_escalation.md

## Common Gotchas (from gotchas.md)
- Verilator error X3: undriven signal → add `assign signal = 0;`
- FAIL on cycle 1: reset not applied before stimulus
- Mismatched widths: Verilator is strict, SystemVerilog widths must match
- Back-pressure deadlock: master/slave READY/VALID never both high
```

---

### 7.7 VLSI Doc Writer Skill

`.claude/skills/vlsi-doc-writer/SKILL.md`:

```markdown
# VLSI Doc Writer — Your Learning Layer

## Trigger
After every successful simulation OR when user runs /teach-me [topic]

## What This Skill Does
Generates clear VLSI learning documentation grounded in YOUR actual RTL.
Not generic textbook content — explains exactly what happened in your design.

## Two Modes

### Mode 1: Auto (after successful simulation)
Topic = what was just verified
Content = explain the protocol/concept using signals from your RTL

### Mode 2: Manual (/teach-me [topic])
Topic = whatever the user asks
Content = explain using mental_model/current.json as concrete example

## Doc Structure Template
# [Topic Name] — Explained Through Your RTL

## What Is [Topic]
[2-3 sentence plain English explanation]

## How It Appears In Your Design
Module: [name from mental model]
Relevant signals: [from mental model port list]

## Signal Behavior (Timing Diagram in ASCII)
clk:   ‾|_|‾|_|‾|_|‾|_
signal: ____|‾‾‾‾|_____

## What Could Go Wrong (and How to Debug)
[Link to relevant entry in memory/debugging.md if exists]

## Key Rules to Remember
1. [rule grounded in your RTL, not generic]
2. ...

## Next Concept to Learn
[suggest next logical VLSI concept]

## Output
Write to: outputs/docs/{topic}_{date}.md
Update: memory/vlsi_concepts.md with topic index entry

## Topics Queue
Track what you've taught in memory/vlsi_concepts.md.
Suggest next concept based on what was just verified.
Progression: ports → clocking → reset → AXI-Lite → AXI4 → interrupts → DMA
```

---

## 8. Hooks

Hooks run automatically on Claude Code events. Place scripts in `.claude/hooks/`.

### Post-Tool-Use Hook

`.claude/hooks/post-tool-use.sh`:

```bash
#!/bin/bash
# Runs after every tool use (Bash, file write, etc.)
# Appends a timestamp to memory so Claude knows what happened when

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Tool used: $CLAUDE_TOOL_NAME" \
  >> ./memory/session_activity.log
```

### Session Start Hook

`.claude/hooks/session-start.sh`:

```bash
#!/bin/bash
# Verifies Ollama is running at session start

if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "⚠️  Ollama is NOT running. Start it with: ollama serve"
  exit 1
fi

echo "✓ Ollama running"
echo "✓ Models available:"
ollama list | grep -E "qwen2.5-coder|mistral"
```

---

## 9. Slash Commands

Place these in `.claude/commands/`. Each is a markdown file with instructions.

### `/vsagent`

`.claude/commands/vsagent.md`:

```markdown
Run the full VLSI Super Agent verification loop.

Steps:
1. Confirm inputs/rtl/ has .v files and inputs/specs/design.txt exists
2. Invoke orchestrator skill
3. Report final result: PASS / FAIL / ESCALATE_TO_HUMAN
```

### `/build-mental-model`

`.claude/commands/build-mental-model.md`:

```markdown
Build or rebuild the mental model from current RTL and spec.
Invoke: mental-model-builder skill
Output: mental_model/current.json
Show diff if previous model exists.
```

### `/run-sim`

`.claude/commands/run-sim.md`:

```markdown
Run simulation on the latest testbench.
Find latest file in outputs/testbenches/
Run: bash tools/run_verilator.sh
Parse and display result.
```

### `/debug-last`

`.claude/commands/debug-last.md`:

```markdown
Debug the most recent simulation failure.
Read: outputs/reports/ (find latest sim log with FAIL)
Extract error lines.
Invoke: debug-agent skill
Show proposed fix.
```

### `/teach-me`

`.claude/commands/teach-me.md`:

```markdown
Generate a VLSI learning document about a specific topic.
Usage: /teach-me [topic]
Examples: /teach-me AXI-Lite, /teach-me clock domains, /teach-me DMA

Invoke: vlsi-doc-writer skill in manual mode.
Always ground explanation in mental_model/current.json.
```

---

## 10. Dual-Model Orchestration

How Qwen and Mistral work together. This is your "custom LLM" equivalent
of what Cadence does with fine-tuned models — you compensate with structure.

```
tools/ollama_client.py
```

```python
import requests
import json

OLLAMA_URL = "http://localhost:11434/api/generate"

PRIMARY_MODEL = "qwen2.5-coder:7b-instruct-q4_K_M"
REVIEW_MODEL  = "mistral:7b-instruct-q4_K_M"

def ask(model: str, system: str, user: str, max_tokens: int = 512) -> str:
    """Call Ollama with strict token limits for your CPU."""
    payload = {
        "model": model,
        "prompt": f"<|system|>\n{system}\n<|user|>\n{user}\n<|assistant|>\n",
        "stream": False,
        "options": {
            "num_predict": max_tokens,
            "temperature": 0.1,       # low = deterministic
            "num_ctx": 2048,          # CRITICAL: keep small for i5
            "repeat_penalty": 1.1
        }
    }
    r = requests.post(OLLAMA_URL, json=payload, timeout=120)
    r.raise_for_status()
    return r.json()["response"].strip()

def generate_and_review(
    system_gen: str, prompt_gen: str,
    system_rev: str, prompt_rev_template: str,
    max_review_cycles: int = 2
) -> dict:
    """
    Full dual-model cycle:
    1. Qwen generates
    2. Mistral reviews
    3. Qwen patches if needed
    Returns: {"output": str, "approved": bool, "cycles": int}
    """
    output = ask(PRIMARY_MODEL, system_gen, prompt_gen)

    for cycle in range(max_review_cycles):
        prompt_rev = prompt_rev_template.format(output=output)
        review_raw = ask(REVIEW_MODEL, system_rev, prompt_rev, max_tokens=256)

        try:
            review = json.loads(review_raw)
        except json.JSONDecodeError:
            # Mistral failed to return JSON — accept output
            return {"output": output, "approved": True, "cycles": cycle}

        if review.get("approved"):
            return {"output": output, "approved": True, "cycles": cycle + 1}

        # Build patch prompt from issues
        issues = review.get("issues", [])
        patch_prompt = f"{prompt_gen}\n\nFix these issues:\n" + "\n".join(
            f"- {i}" for i in issues
        )
        output = ask(PRIMARY_MODEL, system_gen, patch_prompt)

    return {"output": output, "approved": False, "cycles": max_review_cycles}
```

---

## 11. Mental Model Schema

`mental_model/schema_template.json` — copy this to start a new design:

```json
{
  "design_name": "FILL_IN",
  "build_date": "FILL_IN",
  "rtl_version": "v1",
  "rtl_files": [],
  "spec_file": "inputs/specs/design.txt",
  "modules": [
    {
      "name": "FILL_IN",
      "type": "top",
      "ports": {
        "inputs": [
          {"name": "clk", "width": 1, "direction": "input"},
          {"name": "rst_n", "width": 1, "direction": "input"}
        ],
        "outputs": []
      },
      "parameters": {},
      "submodules": []
    }
  ],
  "interfaces": [
    {
      "type": "AXI-Lite",
      "master": "FILL_IN",
      "slave": "FILL_IN",
      "data_width": 32,
      "addr_width": 32,
      "protocol_constraints": []
    }
  ],
  "constraints": [],
  "expected_behavior": [],
  "hierarchy": {
    "top": "FILL_IN",
    "depth": 1,
    "tree": {}
  },
  "coverage_targets": {
    "line": 90,
    "branch": 80,
    "toggle": 70
  }
}
```

---

## 12. Agent Prompt Templates

Stored in each skill folder. Key principle: **pass summaries, not full files**.

Your i5 8th Gen will inference at ~1-3 tokens/sec. Every extra token costs
real time. These templates are tuned for maximum signal per token.

### Mental Model → Test Plan (Qwen prompt)

```
Input budget: ~300 tokens
Output budget: ~400 tokens
Total: ~700 tokens
```

### Test Plan → Testbench (Qwen prompt)

```
Input budget: ~400 tokens (model summary + one test case)
Output budget: ~600 tokens (one testbench at a time)
Total: ~1000 tokens
```

### Simulation Error → Debug Fix (Qwen prompt)

```
Input budget: ~200 tokens (10 error lines + module context)
Output budget: ~300 tokens (JSON with fix)
Total: ~500 tokens
```

**Rule:** Generate ONE test case / ONE testbench at a time.
Never batch. Your CPU cannot handle long outputs reliably.

---

## 13. Execution Loop

`tools/run_verilator.sh`:

```bash
#!/bin/bash
# VLSI Super Agent — Verilator Runner
# Usage: bash tools/run_verilator.sh <rtl.v> <testbench.v>

RTL=$1
TB=$2
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="outputs/reports"
OUTFILE="${OUTDIR}/sim_${TIMESTAMP}.txt"

mkdir -p "$OUTDIR"
mkdir -p "/tmp/verilator_build_${TIMESTAMP}"

echo "=== VLSI Super Agent Simulation ===" | tee "$OUTFILE"
echo "RTL: $RTL" | tee -a "$OUTFILE"
echo "Testbench: $TB" | tee -a "$OUTFILE"
echo "Timestamp: $TIMESTAMP" | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

# Compile
verilator --cc "$RTL" "$TB" \
  --exe --build \
  --Mdir "/tmp/verilator_build_${TIMESTAMP}" \
  -o sim_${TIMESTAMP} \
  2>&1 | tee -a "$OUTFILE"

COMPILE_STATUS=${PIPESTATUS[0]}

if [ $COMPILE_STATUS -ne 0 ]; then
  echo "" | tee -a "$OUTFILE"
  echo "STATUS: COMPILE_ERROR" | tee -a "$OUTFILE"
  echo "ACTION: invoke debug-agent with compile error lines above"
  exit 1
fi

# Run simulation
timeout 60 "/tmp/verilator_build_${TIMESTAMP}/sim_${TIMESTAMP}" \
  2>&1 | tee -a "$OUTFILE"

SIM_STATUS=${PIPESTATUS[0]}

if grep -q "PASS" "$OUTFILE"; then
  echo "" | tee -a "$OUTFILE"
  echo "STATUS: PASS" | tee -a "$OUTFILE"
elif grep -q "FAIL\|Error\|error" "$OUTFILE"; then
  echo "" | tee -a "$OUTFILE"
  echo "STATUS: RUNTIME_FAIL" | tee -a "$OUTFILE"
elif [ $SIM_STATUS -eq 124 ]; then
  echo "" | tee -a "$OUTFILE"
  echo "STATUS: TIMEOUT" | tee -a "$OUTFILE"
fi

echo "Report saved to: $OUTFILE"
```

---

## 14. VLSI Doc Writer

`tools/parse_rtl.py` — extracts ports from your RTL for minimal context:

```python
#!/usr/bin/env python3
"""
Extracts port list from Verilog file.
Outputs compact JSON for mental model building.
Keeps context small — don't pass full RTL to LLM.
"""
import re
import sys
import json

def parse_verilog_ports(filepath: str) -> dict:
    with open(filepath) as f:
        content = f.read()

    # Extract module name
    mod_match = re.search(r'\bmodule\s+(\w+)', content)
    module_name = mod_match.group(1) if mod_match else "unknown"

    # Extract port directions
    ports = {"inputs": [], "outputs": [], "inouts": []}

    for direction in ["input", "output", "inout"]:
        pattern = rf'\b{direction}\s+(?:reg\s+|wire\s+)?(?:\[(\d+):(\d+)\]\s+)?(\w+)'
        for match in re.finditer(pattern, content):
            msb, lsb, name = match.group(1), match.group(2), match.group(3)
            width = (int(msb) - int(lsb) + 1) if msb and lsb else 1
            ports[direction + "s"].append({"name": name, "width": width})

    # Extract parameters
    params = {}
    for match in re.finditer(r'\bparameter\s+(\w+)\s*=\s*(\w+)', content):
        params[match.group(1)] = match.group(2)

    return {
        "module": module_name,
        "file": filepath,
        "ports": ports,
        "parameters": params
    }

if __name__ == "__main__":
    result = parse_verilog_ports(sys.argv[1])
    print(json.dumps(result, indent=2))
```

---

## 15. Build Phases

### Phase 1 — Foundation (Week 1)

**Goal:** Claude Code reads your RTL and builds a valid mental model.

Tasks:
1. Run `claude` in project root
2. Copy your DMA RTL to `inputs/rtl/`
3. Write plain English spec to `inputs/specs/design.txt`
4. Run `/build-mental-model`
5. Verify `mental_model/current.json` is correct
6. Check `/memory` — confirm auto memory is on

**Done when:** mental_model/current.json is built and human-verified.

### Phase 2 — Test Loop (Week 2)

**Goal:** Generate one testbench, run it, and parse result.

Tasks:
1. Run `/vsagent` (will fail at simulation — that's OK)
2. Debug the failure with `/debug-last`
3. Confirm memory/fixes.log gets an entry
4. Get one PASS

**Done when:** one PASS with self-checking testbench.

### Phase 3 — Full Loop + Docs (Week 3)

**Goal:** Complete closed-loop with doc generation.

Tasks:
1. Run 5 test cases through the full loop
2. Verify outputs/docs/ has VLSI concept files
3. Confirm memory/vlsi_concepts.md tracks your learning
4. Add Byterover MCP for persistent cross-session memory search

**Done when:** 5 passing test cases + 3 VLSI doc files generated.

### Phase 4 — Scale (Week 4+)

**Goal:** Apply to full DMA subsystem + expand to Transformer Attention Accelerator.

Tasks:
1. Add all DMA submodules to mental model
2. Generate integration-level testbenches
3. Start `inputs/rtl/` for Streaming Transformer project
4. Build separate mental model for attention accelerator

---

## 16. RAM Budget

| Component | RAM Usage |
|---|---|
| Ubuntu OS (idle) | ~1.5 GB |
| Qwen2.5-Coder 7B Q4_K_M | ~4.5 GB |
| Mistral 7B Q4_K_M | ~4.5 GB |
| Python tools | ~150 MB |
| Verilator | ~200 MB |
| Claude Code terminal | ~100 MB |

**Problem:** You cannot run both models simultaneously. 4.5 + 4.5 = 9 GB > 8 GB.

**Solution — Model Swapping:**

```bash
# In tools/ollama_client.py — load/unload per call
# Ollama unloads inactive models after 5 minutes by default
# Set OLLAMA_KEEP_ALIVE=0 to unload immediately after use

# In .claude/settings.json or ~/.bashrc:
export OLLAMA_KEEP_ALIVE=0
```

With `OLLAMA_KEEP_ALIVE=0`: Qwen generates → unloads → Mistral reviews → unloads.
Sequential, not parallel. 4.5 GB peak, not 9 GB.

**Practical RAM budget with swapping:**
| Active Component | RAM |
|---|---|
| OS + Claude Code | ~1.7 GB |
| ONE model at a time | ~4.5 GB |
| Verilator (during sim) | ~200 MB |
| **Total peak** | **~6.4 GB** ✓ |

---

## 17. First Session Script

Run this in Claude Code after setup. Copy-paste as your first prompt:

```
I am starting the VLSI Super Agent project. Please:

1. Read CLAUDE.md to understand the project
2. Check /memory for any previous session context
3. Verify Ollama is running: run `curl http://localhost:11434/api/tags`
4. Verify Verilator is installed: run `verilator --version`
5. List files in inputs/rtl/ and inputs/specs/
6. Tell me what is ready and what is missing before we start

Do not build the mental model yet. Just verify the setup is correct.
```

Then after that confirmation, run:

```
Run /build-mental-model on the RTL in inputs/rtl/
```

Then:

```
Run /vsagent — start the full verification loop
```

---

## Quick Reference Card

```
SESSION START:
  claude                           ← always launch from project root
  /memory                          ← check what was remembered

BUILD MENTAL MODEL:
  /build-mental-model              ← parse RTL + spec → JSON

FULL LOOP:
  /vsagent                         ← generate → simulate → debug → doc

INDIVIDUAL STEPS:
  /run-sim                         ← just simulate latest testbench
  /debug-last                      ← debug latest failure
  /teach-me AXI-Lite               ← generate VLSI learning doc

MEMORY:
  /memory                          ← view + edit all memory files
  "remember that X for module Y"  ← Claude writes to auto memory

MODELS:
  Primary: qwen2.5-coder:7b-instruct-q4_K_M   (generates)
  Review:  mistral:7b-instruct-q4_K_M          (validates)
  Swap:    OLLAMA_KEEP_ALIVE=0                  (prevents OOM)

KEY FILES:
  CLAUDE.md                        ← project brain (edit this)
  mental_model/current.json        ← chip ground truth
  memory/MEMORY.md                 ← session learnings
  memory/fixes.log                 ← debug history
  outputs/docs/                    ← your VLSI learning
```

---

*This PRD is living documentation. Update CLAUDE.md as the system evolves.*
*Every architectural decision belongs in memory/decisions.log.*
