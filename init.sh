#!/bin/bash
# init.sh - bash-tools main entry point
#
# Usage: source /path/to/bash-tools/init.sh

# Prevent duplicate loading
if [[ -n "${_BASH_TOOLS_LOADED:-}" ]]; then
  return 0
fi
_BASH_TOOLS_LOADED=1

# Get script directory
if [[ -n "${BASH_SOURCE:-}" ]]; then
  BASH_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${(%):-%x}" ]]; then
  # zsh
  BASH_TOOLS_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  echo "Cannot determine bash-tools directory" >&2
  return 1
fi

# Load core library
source "$BASH_TOOLS_DIR/lib/alias_map.sh"

# Load commands
source "$BASH_TOOLS_DIR/lib/to.sh"
source "$BASH_TOOLS_DIR/lib/dev.sh"
source "$BASH_TOOLS_DIR/lib/file.sh"
source "$BASH_TOOLS_DIR/lib/web.sh"
source "$BASH_TOOLS_DIR/lib/sync.sh"
source "$BASH_TOOLS_DIR/lib/todo.sh"
source "$BASH_TOOLS_DIR/lib/md.sh"

# Load completion (zsh only)
if [[ -n "${ZSH_VERSION:-}" ]]; then
  source "$BASH_TOOLS_DIR/lib/completion.sh"
fi
