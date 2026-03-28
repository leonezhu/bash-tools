#!/bin/bash
# to.sh - Directory navigation command
#
# Usage:
#   to <alias|path> - Jump to directory by alias or full path
#   to add <alias> <path> - Add directory alias (./path stored as relative)
#   to rm <alias>   - Remove directory alias
#   to ls           - List all directory aliases

to() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: to <alias|path> | to s [pattern] | to add <alias> <path> | to rm <alias> | to ls" >&2
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
      echo "Directory navigation with aliases or full paths"
      echo ""
      echo "Usage:"
      echo "  to <alias|path>      - Jump to directory by alias or full path"
      echo "  to s [pattern]       - Search files in current dir"
      echo "  to s [alias|path] [pattern] - Search files in specified dir"
      echo "  to add <alias> <dir> - Add directory alias"
      echo "                        (paths starting with . are stored as relative)"
      echo "  to rm <alias>        - Remove directory alias"
      echo "  to ls                - List all directory aliases"
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
          # If target is a file, cd to its parent directory
          if [[ -f "$target" ]]; then
            cd "$(dirname "$target")"
          else
            cd "$target"
          fi
        else
          echo "Path does not exist: $target" >&2
          return 1
        fi
      else
        echo "Unknown alias: $cmd" >&2
        echo "Use 'to add $cmd <path>' to add it." >&2
        return 1
      fi
      ;;
  esac
}
