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
echo "Per project, copy the posture and templates into the project root:"
echo "  cp ${KIT_DIR}/AGENTS.md       /path/to/YourApp/AGENTS.md"
echo "  cp ${KIT_DIR}/templates/*     /path/to/YourApp/Sources/"
echo
echo "For surgical Swift edits (recommended):"
echo "  pip install vibe-fim   # see skills/ios-surgical-edit.md"
