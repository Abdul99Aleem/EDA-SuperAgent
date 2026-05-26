---
name: vlsi-doc-writer
description: Generates VLSI learning documentation grounded in actual RTL
---

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
```markdown
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
```

## Output
Write to: outputs/docs/{topic}_{date}.md
Update: memory/vlsi_concepts.md with topic index entry

## Topics Queue
Track what you've taught in memory/vlsi_concepts.md.
Suggest next concept based on what was just verified.
Progression: ports → clocking → reset → AXI-Lite → AXI4 → interrupts → DMA

## Token Budget
- Mental model context: ~200 tokens
- Generated doc: ~800 tokens
- Total: ~1000 tokens
