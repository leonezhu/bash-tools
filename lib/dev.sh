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
      echo "Usage: dev <alias|path> | dev add <alias> <path> | dev rm <alias> | dev ls" >&2
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
      echo "Open directory in VS Code with aliases or full paths"
      echo ""
      echo "Usage:"
      echo "  dev <alias|path>     - Open directory in VS Code"
      echo "  dev add <alias> <dir> - Add directory alias"
      echo "                        (paths starting with . are stored as relative)"
      echo "  dev rm <alias>       - Remove directory alias"
      echo "  dev ls               - List all directory aliases"
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
