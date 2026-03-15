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
      echo "Usage: to <alias|path> | to add <alias> <path> | to rm <alias> | to ls" >&2
      return 1
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
      echo "  to add <alias> <dir> - Add directory alias"
      echo "                        (paths starting with . are stored as relative)"
      echo "  to rm <alias>        - Remove directory alias"
      echo "  to ls                - List all directory aliases"
      ;;
    *)
      local target

      # Check if it's a full path (starts with /, ./, ~, or ../)
      if [[ "$cmd" == /* || "$cmd" == .* || "$cmd" == ~* ]]; then
        target="${cmd/#\~/$HOME}"
      else
        # Try to resolve alias
        target="$(_resolve_alias "$cmd")"
      fi

      if [[ -n "$target" ]]; then
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
