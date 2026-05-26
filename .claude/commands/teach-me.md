---
name: teach-me
description: Generate a VLSI learning document about a specific topic
---

Generate a VLSI learning document about a specific topic.

Usage: /teach-me [topic]

Examples: 
- /teach-me AXI-Lite
- /teach-me clock domains
- /teach-me DMA
- /teach-me reset strategies

Steps:
1. Load mental_model/current.json for concrete examples
2. Invoke vlsi-doc-writer skill in manual mode
3. Generate documentation grounded in YOUR actual RTL
4. Output to outputs/docs/{topic}_{date}.md
5. Update memory/vlsi_concepts.md with topic index

Always ground explanation in mental_model/current.json - use your actual signals and modules as examples, not generic textbook content.
