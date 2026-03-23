#!/bin/bash
# ob.sh - Obsidian CLI wrapper with smart search
#
# Usage:
#   ob s <query>     - Search notes with fzf selector
#   ob <file>        - Open file directly
#   ob               - Show help

ob() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Obsidian CLI wrapper"
      echo ""
      echo "Usage:"
      echo "  ob s <query>   - Search notes with fzf selector"
      echo "  ob <file>      - Open file directly"
      ;;
    s|search)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: ob s <query>" >&2
        return 1
      fi

      # Build query from remaining arguments
      local query="${2:-}"
      shift 2
      if [[ $# -gt 0 ]]; then
        query="$query $*"
      fi

      # Run search and capture output
      local search_output
      search_output=$(obsidian search query="$query" 2>&1)

      # Filter out warning/info lines (keep only file paths)
      local results
      results=$(echo "$search_output" | grep -v "^202[0-9]-" | grep -v "Loading updated app package" | grep -v "installer is out of date" | grep -v "^$" || true)

      # Check if we have results
      if [[ -z "$results" ]]; then
        echo "No results found for: $query"
        return 1
      fi

      # Count results
      local count
      count=$(echo "$results" | grep -c . || echo "0")

      if [[ "$count" -eq 1 ]]; then
        # Single result - auto open
        local file_path
        file_path=$(echo "$results" | head -1)
        echo "Opening: $file_path"
        obsidian open file="$file_path" 2>&1 | grep -v "^202[0-9]-" | grep -v "Loading updated app package" | grep -v "installer is out of date" || true
      else
        # Multiple results - use fzf selector
        if ! command -v fzf &>/dev/null; then
          echo "Multiple results found (fzf not installed, showing list):"
          echo "$results" | nl -w3 -s'. '
          echo ""
          echo "Install fzf for interactive selection: brew install fzf"
          return 0
        fi

        local selected
        selected=$(echo "$results" | fzf --height=40% --layout=reverse --border --prompt="Obsidian> ")

        if [[ -n "$selected" ]]; then
          echo "Opening: $selected"
          obsidian open file="$selected" 2>&1 | grep -v "^202[0-9]-" | grep -v "Loading updated app package" | grep -v "installer is out of date" || true
        fi
      fi
      ;;
    help|--help|-h)
      ob
      ;;
    *)
      # Treat as file path to open
      obsidian open file="$cmd" 2>&1 | grep -v "^202[0-9]-" | grep -v "Loading updated app package" | grep -v "installer is out of date" || true
      ;;
  esac
}
