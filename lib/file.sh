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
      echo "Usage: file <alias|path> | file s [pattern] | file add <alias> <path> | file rm <alias> | file ls" >&2
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
        if [[ "$2" == /* || "$2" == ~* ]]; then
          search_dir="$2"
          search_pattern=""
        else
          local resolved
          resolved="$(_resolve_alias "$2")"
          if [[ -n "$resolved" ]]; then
            search_dir="$resolved"
            search_pattern=""
          elif [[ "$2" == .* && -e "$2" ]]; then
            search_dir="$2"
            search_pattern=""
          else
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
      echo "Open directory in Finder with aliases or full paths"
      echo ""
      echo "Usage:"
      echo "  file <alias|path>    - Open directory in Finder"
      echo "  file s [pattern]     - Search files in current dir"
      echo "  file s [alias|path] [pattern] - Search files in specified dir"
      echo "  file add <alias> <dir> - Add directory alias"
      echo "                        (paths starting with . are stored as relative)"
      echo "  file rm <alias>      - Remove directory alias"
      echo "  file ls              - List all directory aliases"
      ;;
    *)
      local target
      local is_full_path=false

      # Try alias resolution first (for all inputs)
      target="$(_resolve_alias "$cmd")"
      if [[ -n "$target" ]]; then
        is_full_path=false
      elif [[ "$cmd" == /* || "$cmd" == ~* ]]; then
        target="${cmd/#\~/$HOME}"
        is_full_path=true
      elif [[ "$cmd" == .* ]]; then
        local stripped="${cmd/#./}"
        stripped="${stripped/#../}"
        stripped="${stripped/#.}"
        target="$(_resolve_alias "$stripped")"
        if [[ -n "$target" ]]; then
          is_full_path=false
        elif [[ -e "$cmd" ]]; then
          target="$cmd"
          is_full_path=true
        fi
      fi

      # Convert relative path to absolute path
      if [[ -n "$target" && "$target" != /* ]]; then
        if [[ -d "$target" ]]; then
          # For directories, use cd + pwd
          target="$(cd "$target" 2>/dev/null && pwd)"
        else
          # For files, use dirname + basename
          target="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
        fi
      fi

      if [[ -n "$target" ]]; then
        if [[ -e "$target" ]]; then
          # Auto-add alias for full paths (only if path exists)
          if [[ "$is_full_path" == true ]]; then
            _auto_add_dir_alias "$target"
          fi

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
