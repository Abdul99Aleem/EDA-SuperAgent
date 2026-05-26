---
name: build-mental-model
description: Build or rebuild the mental model from current RTL and spec
---

Build or rebuild the mental model from current RTL and spec.

Steps:
1. Check inputs/rtl/ for .v files
2. Check inputs/specs/design.txt exists
3. Invoke mental-model-builder skill
4. Output: mental_model/current.json
5. Show diff if previous model exists

This is the foundation of the entire system. The mental model is the ground truth
that raises test correctness from 42% to 83% (per Cadence ChipStack paper).
