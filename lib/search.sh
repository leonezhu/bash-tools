#!/bin/bash
# search.sh - Shared search and execute functionality
#
# Usage:
#   _search_and_execute <directory> [pattern] [file_filter] [handler]
#
# Parameters:
#   directory   - Directory to search in
#   pattern     - Fuzzy search pattern (optional)
#   file_filter - Glob pattern like "*.md" (optional)
#   handler     - Function name to call with selected file (optional, defaults to executing the file)

# Search files in directory and let user select one to execute
_search_and_execute() {
  local dir="$1"
  local pattern="${2:-}"
  local file_filter="${3:-}"
  local handler="${4:-}"

  # Check if fzf is available
  if ! command -v fzf &>/dev/null; then
    echo "Error: fzf is required but not installed." >&2
    echo "Install with: brew install fzf" >&2
    return 1
  fi

  # Build find command
  local find_cmd
  if [[ -n "$file_filter" ]]; then
    find_cmd="find \"$dir\" -type f -name \"$file_filter\" -not -path '*/\.*' 2>/dev/null"
  else
    find_cmd="find \"$dir\" -type f -not -path '*/\.*' 2>/dev/null"
  fi

  # fzf options
  local fzf_opts=("--height=40%" "--layout=reverse" "--border" "--prompt=Select> ")

  if [[ -n "$pattern" ]]; then
    fzf_opts+=("--query=$pattern")
  fi

  # Search and select file
  local selected
  selected=$(eval "$find_cmd" | fzf "${fzf_opts[@]}")

  # If a file was selected
  if [[ -n "$selected" ]]; then
    echo "Selected: $selected"

    # If a handler function is provided, use it
    if [[ -n "$handler" ]]; then
      "$handler" "$selected"
    elif [[ -x "$selected" ]]; then
      # File is executable
      echo "Executing..."
      "$selected"
    else
      # Try to determine how to handle the file
      local ext="${selected##*.}"
      case "$ext" in
        sh)
          echo "Running shell script..."
          bash "$selected"
          ;;
        py)
          echo "Running Python script..."
          python3 "$selected"
          ;;
        js)
          echo "Running Node.js script..."
          node "$selected"
          ;;
        *)
          # Make executable and run
          echo "Making executable and running..."
          chmod +x "$selected"
          "$selected"
          ;;
      esac
    fi
  fi
}
