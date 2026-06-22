#!/usr/bin/env bash
# Install the iOS Builder agent into vibe, and print how to use the kit.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${HOME}/.vibe/agents"

mkdir -p "${AGENTS_DIR}"
ln -sf "${KIT_DIR}/agents/ios.toml" "${AGENTS_DIR}/ios.toml"
echo "Linked ${AGENTS_DIR}/ios.toml -> ${KIT_DIR}/agents/ios.toml"

echo
echo "Use it:"
echo "  vibe --agent ios"
echo
echo "Per project, copy the posture, patterns and templates into the project root:"
echo "  cp ${KIT_DIR}/AGENTS.md       /path/to/YourApp/AGENTS.md"
echo "  cp ${KIT_DIR}/PATTERNS.md     /path/to/YourApp/PATTERNS.md"
echo "  cp ${KIT_DIR}/templates/*     /path/to/YourApp/Sources/"
echo
echo "For surgical, agent-invoked Swift edits (recommended):"
echo "  pip install \"vibe-fim[mcp]\"   # provides vibe-fim-mcp, wired in agents/ios.toml"
if command -v vibe-fim-mcp >/dev/null 2>&1; then
  echo "  vibe-fim-mcp is on PATH — the surgical_patch tool will load in 'vibe --agent ios'."
else
  echo "  NOTE: vibe-fim-mcp is not on PATH yet; install it so the tool loads."
fi
echo
echo "Gate your Swift sources with the posture lint:"
echo "  ${KIT_DIR}/bin/vibe-ios-doctor Sources/"
