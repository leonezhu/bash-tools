#!/bin/bash
# file.sh - Open directory in Finder
#
# Usage:
#   file <alias|path> - Open directory in Finder by alias or full path
#   file add <alias> <path> - Add directory alias (./path stored as relative)
#   file rm <alias> - Remove directory alias
#   file ls         - List all directory aliases

file() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: file <alias|path> | file add <alias> <path> | file rm <alias> | file ls" >&2
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
      echo "Open directory in Finder with aliases or full paths"
      echo ""
      echo "Usage:"
      echo "  file <alias|path>    - Open directory in Finder"
      echo "  file add <alias> <dir> - Add directory alias"
      echo "                        (paths starting with . are stored as relative)"
      echo "  file rm <alias>      - Remove directory alias"
      echo "  file ls              - List all directory aliases"
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
          # Use -R to reveal file in Finder, or open directory directly
          if [[ -f "$target" ]]; then
            open -R "$target"
          else
            open "$target"
          fi
        else
          echo "Path does not exist: $target" >&2
          return 1
        fi
      else
        echo "Unknown alias: $cmd" >&2
        echo "Use 'file add $cmd <path>' to add it." >&2
        return 1
      fi
      ;;
  esac
}
