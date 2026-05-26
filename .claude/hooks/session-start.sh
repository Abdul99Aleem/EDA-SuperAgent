#!/bin/bash
# Session Start Hook
# Verifies Ollama is running at session start

if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "⚠️  Ollama is NOT running. Start it with: ollama serve"
  exit 1
fi

echo "✓ Ollama running"
echo "✓ Models available:"
ollama list | grep -E "qwen2.5-coder|mistral"

# Check if Vivado is available
if ! command -v vivado &> /dev/null; then
  echo "⚠️  Vivado not found in PATH"
  echo "   Make sure Vivado is installed and sourced"
else
  echo "✓ Vivado available"
fi
