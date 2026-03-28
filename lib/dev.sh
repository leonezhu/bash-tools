#!/bin/bash
# dev.sh - Open directory in VS Code
#
# Usage:
#   dev <alias|path> - Open directory in VS Code by alias or full path
#   dev add <alias> <path> - Add directory alias (./path stored as relative)
#   dev rm <alias>  - Remove directory alias
#   dev ls          - List all directory aliases

dev() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: dev <alias|path> | dev s [pattern] | dev add <alias> <path> | dev rm <alias> | dev ls" >&2
      return 1
      ;;
    s|search)
      local search_dir search_pattern
      # Smart argument parsing:
      # - No args: search current dir, no pattern
      # - One arg starting with path prefix: search that dir, no pattern
      # - One arg not a path: search current dir with that pattern
      # - Two args: first is dir, second is pattern
      if [[ -z "${2:-}" ]]; then
        search_dir="."
        search_pattern=""
      elif [[ -z "${3:-}" ]]; then
        # Only one argument provided
        if [[ "$2" == /* || "$2" == .* || "$2" == ~* ]]; then
          # Looks like a path
          search_dir="$2"
          search_pattern=""
        else
          # Try to resolve as alias first
          local resolved
          resolved="$(_resolve_alias "$2")"
          if [[ -n "$resolved" ]]; then
            search_dir="$resolved"
            search_pattern=""
          else
            # Not an alias, treat as pattern
            search_dir="."
            search_pattern="$2"
          fi
        fi
      else
        # Two arguments: dir and pattern
        search_dir="$2"
        search_pattern="$3"
      fi
      # Normalize path
      search_dir="${search_dir/#\~/$HOME}"
      _search_and_execute "$search_dir" "$search_pattern"
      ;;
    add)
      _add_alias "dir" "$2" "$3"
      ;;
    rm)
      # Try to remove from both dir and rel types
      _remove_alias "dir" "$2" 2>/dev/null || _remove_alias "rel" "$2"
      ;;
    ls|list)
      _list_aliases "dir"
      _list_aliases "rel"
      ;;
    help|--help|-h)
      echo "Open directory in VS Code with aliases or full paths"
      echo ""
      echo "Usage:"
      echo "  dev <alias|path>     - Open directory in VS Code"
      echo "  dev s [pattern]       - Search files in current dir"
      echo "  dev s [alias|path] [pattern] - Search files in specified dir"
      echo "  dev add <alias> <dir> - Add directory alias"
      echo "                        (paths starting with . are stored as relative)"
      echo "  dev rm <alias>       - Remove directory alias"
      echo "  dev ls               - List all directory aliases"
      ;;
    *)
      local target
      local is_full_path=false
      local should_auto_alias=true

      # Skip auto-alias for special paths
      case "$cmd" in
        .|..) should_auto_alias=false ;;
      esac

      # Check if it's a full path (starts with /, ./, ~, or ../)
      if [[ "$cmd" == /* || "$cmd" == .* || "$cmd" == ~* ]]; then
        target="${cmd/#\~/$HOME}"
        is_full_path=true
      else
        # Try to resolve alias
        target="$(_resolve_alias "$cmd")"
      fi

      # Convert relative path to absolute path
      if [[ -n "$target" && "$target" != /* ]]; then
        target="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
      fi

      if [[ -n "$target" ]]; then
        # Auto-add alias for full paths (skip special paths like . and ..)
        if [[ "$is_full_path" == true && "$should_auto_alias" == true ]]; then
          _auto_add_dir_alias "$target"
        fi

        if [[ -e "$target" ]]; then
          code "$target"
        else
          echo "Path does not exist: $target" >&2
          return 1
        fi
      else
        echo "Unknown alias: $cmd" >&2
        echo "Use 'dev add $cmd <path>' to add it." >&2
        return 1
      fi
      ;;
  esac
}
