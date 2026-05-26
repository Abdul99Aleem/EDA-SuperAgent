# VLSI Super Agent

An agentic RTL verification system based on Cadence ChipStack AI Super Agent architecture.

## System Overview

- **Hardware**: i5 8th Gen, 8GB RAM, no GPU
- **Primary Model**: Qwen2.5-Coder:7b-instruct-q4_K_M (generation)
- **Review Model**: Mistral:7b-instruct-q4_K_M (validation)
- **Simulation**: Vivado xsim (batch mode)
- **Platform**: Claude Code

## Quick Start

### Prerequisites

1. **Ollama** with models installed:
   ```bash
   ollama pull qwen2.5-coder:7b-instruct-q4_K_M
   ollama pull mistral:7b-instruct-q4_K_M
   ollama serve  # Keep running in background
   ```

2. **Vivado** installed and sourced:
   ```bash
   source /path/to/Vivado/2023.x/settings64.sh
   vivado -version  # Verify it works
   ```

3. **Python 3** with requests library:
   ```bash
   pip3 install requests
   ```

4. **Set environment variable** for model swapping:
   ```bash
   export OLLAMA_KEEP_ALIVE=0  # Add to ~/.bashrc
   ```

### First Session

1. **Add your RTL files** to `inputs/rtl/`
2. **Create design spec** in `inputs/specs/design.txt` (use template)
3. **Launch Claude Code** from project root:
   ```bash
   cd /home/aleem/Desktop/VLSI_SUPER_AGENTS
   claude
   ```

4. **Run first command**:
   ```
   /build-mental-model
   ```

5. **Run full verification loop**:
   ```
   /vsagent
   ```

## Available Commands

- `/vsagent` - Run full verification loop
- `/build-mental-model` - Build/rebuild mental model from RTL
- `/run-sim` - Run simulation on latest testbench
- `/debug-last` - Debug most recent failure
- `/teach-me [topic]` - Generate VLSI learning doc

## Project Structure

```
.
├── CLAUDE.md                    # Project brain (loaded every session)
├── .claude/
│   ├── settings.json            # Permissions and model config
│   ├── skills/                  # Agent skills (7 agents)
│   ├── commands/                # Slash commands
│   ├── hooks/                   # Session hooks
│   └── rules/                   # Domain-specific rules
├── inputs/
│   ├── rtl/                     # Your Verilog files go here
│   └── specs/                   # Design specifications
├── mental_model/
│   └── current.json             # Ground truth mental model
├── memory/                      # Auto-maintained by Claude
│   ├── MEMORY.md                # Session learnings index
│   ├── debugging.md             # Failure patterns
│   ├── fixes.log                # Bug fix history
│   └── vlsi_concepts.md         # Concepts learned
├── outputs/
│   ├── testbenches/             # Generated testbenches
│   ├── reports/                 # Simulation results
│   ├── test_plans/              # Test plans
│   └── docs/                    # VLSI learning docs
└── tools/
    ├── run_vivado.tcl           # Vivado batch simulation
    ├── parse_rtl.py             # RTL port extractor
    └── ollama_client.py         # Dual-model orchestration
```

## Phase 1 Implementation

Currently implements coverage-driven loop:
- Mental model → Test plan → Codegen → Simulation → Coverage

NOT yet implemented:
- Advanced stimulus generation
- Assertion-based verification
- Result analyzer agents

## Memory System

Claude Code automatically maintains memory:
- `MEMORY.md` - Index (first 200 lines loaded every session)
- `debugging.md` - Common failure patterns
- `fixes.log` - Every bug fixed with root cause
- `vlsi_concepts.md` - VLSI concepts you've learned

## Dual-Model Review

Every generation task uses two models:
1. **Qwen2.5-Coder** generates (test plan, testbench, fix)
2. **Mistral** reviews and flags issues
3. **Qwen** patches if needed
4. Max 2 cycles before escalation

Sequential loading (OLLAMA_KEEP_ALIVE=0) keeps RAM under 8GB.

## Token Budget

All prompts kept under 2048 tokens for i5 CPU:
- Use `parse_rtl.py` to extract ports (don't read full .v files)
- Pass summaries to LLMs, not full documents
- Generate ONE test case at a time

## Troubleshooting

### Ollama not running
```bash
ollama serve &
```

### Vivado not found
```bash
source /path/to/Vivado/settings64.sh
```

### Out of memory
```bash
export OLLAMA_KEEP_ALIVE=0
# Restart ollama serve
```

### Models not found
```bash
ollama list
ollama pull qwen2.5-coder:7b-instruct-q4_K_M
ollama pull mistral:7b-instruct-q4_K_M
```

## References

- Based on: Cadence ChipStack AI Super Agent architecture
- Mental model approach: 42% → 83% test correctness improvement
- Claude Code: https://claude.ai/code

## License

MIT
