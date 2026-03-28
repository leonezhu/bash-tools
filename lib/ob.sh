#!/bin/bash
# ob.sh - Obsidian CLI wrapper with smart search
#
# Usage:
#   ob s <query>     - Search notes with fzf selector
#   ob <file>        - Open file directly
#   ob               - Show help

# Vault path - adjust if your vault is elsewhere
: "${OBSIDIAN_VAULT:="$HOME/Documents/GitHub/notes"}"

# Simple URL encoder (minimal, for paths)
_url_encode() {
  local string="$1"
  # Keep simple - only replace spaces and special characters commonly in file paths
  printf '%s' "$string" | sed 's/ /%20/g; s/&/%26/g; s/#/%23/g; s/?/%3F/g'
}

# Convert file path to obsidian:// URI format
_obsidian_uri() {
  local file="$1"
  local vault_name
  vault_name=$(basename "$OBSIDIAN_VAULT")

  # Get path relative to vault
  local rel_path="${file#$OBSIDIAN_VAULT/}"

  # URL encode the path
  local encoded_path
  encoded_path=$(_url_encode "$rel_path")

  echo "obsidian://open?vault=${vault_name}&file=${encoded_path}"
}

# Search markdown files using ripgrep
_ob_search() {
  local query="$1"
  local results

  if command -v rg &>/dev/null; then
    results=$(rg -l -i "$query" "$OBSIDIAN_VAULT" --type md 2>/dev/null)
  else
    results=$(find "$OBSIDIAN_VAULT" -type f -iname "*.md" -exec grep -l -i "$query" {} \; 2>/dev/null)
  fi

  echo "$results"
}

ob() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Obsidian CLI wrapper (using obsidian:// URI scheme)"
      echo ""
      echo "Usage:"
      echo "  ob s <query>   - Search notes with fzf selector"
      echo "  ob <file>      - Open file directly"
      echo ""
      echo "Vault path: Set OBSIDIAN_VAULT env var (default: ~/Documents/GitHub/notes)"
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

      # Run search
      local results
      results=$(_ob_search "$query")

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
        open -g "$(_obsidian_uri "$file_path")"
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
          open -g "$(_obsidian_uri "$selected")"
        fi
      fi
      ;;
    help|--help|-h)
      ob
      ;;
    *)
      # Treat as file path to open
      local file_path="$cmd"

      # If not absolute path, look in current directory or vault
      if [[ ! "$file_path" = /* ]]; then
        if [[ -f "$file_path" ]]; then
          file_path="$(pwd)/$file_path"
        elif [[ -f "$OBSIDIAN_VAULT/$file_path" ]]; then
          file_path="$OBSIDIAN_VAULT/$file_path"
        elif [[ -f "$OBSIDIAN_VAULT/$cmd.md" ]]; then
          file_path="$OBSIDIAN_VAULT/$cmd.md"
        else
          echo "File not found: $cmd" >&2
          return 1
        fi
      fi

      if [[ -f "$file_path" ]]; then
        echo "Opening: $file_path"
        open -g "$(_obsidian_uri "$file_path")"
      else
        echo "File not found: $file_path" >&2
        return 1
      fi
      ;;
  esac
}
