#!/bin/bash
# path.sh - Copy file/directory path to clipboard
#
# Usage:
#   path <alias|path>    - Copy path to clipboard
#   path s [dir] [pattern] - Search and copy selected file path
#   path add <alias> <path> - Add path alias
#   path rm <alias>      - Remove alias
#   path ls              - List all aliases

# Main command
path() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      _path_usage
      return 1
      ;;
    s|search)
      local search_dir search_pattern
      # Smart argument parsing (same pattern as other commands)
      if [[ -z "${2:-}" ]]; then
        search_dir="."
        search_pattern=""
      elif [[ -z "${3:-}" ]]; then
        if [[ "$2" == /* || "$2" == .* || "$2" == ~* ]]; then
          search_dir="$2"
          search_pattern=""
        else
          local resolved
          resolved="$(_resolve_alias "$2")"
          if [[ -n "$resolved" ]]; then
            search_dir="$resolved"
            search_pattern=""
          else
            search_dir="."
            search_pattern="$2"
          fi
        fi
      else
        search_dir="$2"
        search_pattern="$3"
      fi
      # Normalize path
      search_dir="${search_dir/#\~/$HOME}"
      _search_and_execute "$search_dir" "$search_pattern" "" "_path_copy"
      ;;
    add)
      shift
      _add_alias "dir" "$1" "$2"
      ;;
    rm)
      shift
      _remove_alias "dir" "$1" 2>/dev/null || _remove_alias "rel" "$1"
      ;;
    ls|list)
      echo "Path aliases:"
      _list_aliases "dir"
      _list_aliases "rel"
      ;;
    help|--help|-h)
      _path_usage
      ;;
    *)
      _path_copy "$cmd"
      ;;
  esac
}

# Copy path to clipboard
_path_copy() {
  local target="$1"
  local is_full_path=false
  local file_path

  # Check if it's a full path
  if [[ "$target" == /* || "$target" == .* || "$target" == ~* ]]; then
    file_path="${target/#\~/$HOME}"
    is_full_path=true
  else
    # Try to resolve alias
    file_path="$(_resolve_alias "$target")"
    # If alias not found, treat as relative path
    if [[ -z "$file_path" ]]; then
      file_path="$target"
    fi
  fi

  # Convert relative path to absolute path
  if [[ "$file_path" != /* ]]; then
    if [[ -d "$file_path" ]]; then
      # For directories, use cd + pwd
      file_path="$(cd "$file_path" 2>/dev/null && pwd)"
    else
      # For files, use dirname + basename
      file_path="$(cd "$(dirname "$file_path")" 2>/dev/null && pwd)/$(basename "$file_path")"
    fi
  fi

  # Check if path exists
  if [[ ! -e "$file_path" ]]; then
    echo "Path not found: $file_path" >&2
    return 1
  fi

  # Auto-add alias for full paths (after converting to absolute path)
  if [[ "$is_full_path" == true ]]; then
    _auto_add_dir_alias "$file_path"
  fi

  # Copy to clipboard
  if command -v pbcopy &>/dev/null; then
    echo -n "$file_path" | pbcopy
    echo "Copied to clipboard: $file_path"
  elif command -v xclip &>/dev/null; then
    echo -n "$file_path" | xclip -selection clipboard
    echo "Copied to clipboard: $file_path"
  elif command -v xsel &>/dev/null; then
    echo -n "$file_path" | xsel --clipboard --input
    echo "Copied to clipboard: $file_path"
  else
    echo "No clipboard utility found (pbcopy/xclip/xsel)" >&2
    echo "Path: $file_path"
    return 1
  fi
}

# Usage help
_path_usage() {
  cat << 'EOF'
Copy file/directory path to clipboard

Usage:
  path <alias|path>    - Copy path to clipboard
  path s [pattern]     - Search files in current dir and copy path
  path s [dir] [pattern] - Search in specified dir and copy path
  path add <alias> <path> - Add path alias
  path rm <alias>      - Remove alias
  path ls              - List all aliases
  path help            - Show this help

Examples:
  path README.md              # Copy local file path
  path ~/Projects/myapp       # Copy directory path
  path myproject              # Copy alias path
  path s                      # Search all files in current dir
  path s api                  # Search files with 'api' pattern
  path s myproject test       # Search 'test' files in alias 'myproject'
  path add mydoc ~/docs/mydoc # Add alias

Features:
  - Auto-converts relative paths to absolute paths
  - Works with both files and directories
  - Cross-platform clipboard support (macOS/Linux)
EOF
}
