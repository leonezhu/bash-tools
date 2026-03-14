#!/bin/bash
# web.sh - Open URL in browser
#
# Usage:
#   web <alias>     - Open URL in default browser by alias
#   web add <alias> <url> - Add URL alias
#   web rm <alias>  - Remove URL alias
#   web ls          - List all URL aliases

web() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: web <alias> | web add <alias> <url> | web rm <alias> | web ls" >&2
      return 1
      ;;
    add)
      _add_alias "url" "$2" "$3"
      ;;
    rm)
      _remove_alias "url" "$2"
      ;;
    ls|list)
      _list_aliases "url"
      ;;
    help|--help|-h)
      echo "Open URL in browser with aliases"
      echo ""
      echo "Usage:"
      echo "  web <alias>          - Open URL in default browser"
      echo "  web add <alias> <url> - Add URL alias"
      echo "  web rm <alias>       - Remove URL alias"
      echo "  web ls               - List all URL aliases"
      ;;
    *)
      local url
      url="$(_get_url_alias "$cmd")"
      if [[ -n "$url" ]]; then
        open "$url"
      else
        echo "Unknown alias: $cmd" >&2
        echo "Use 'web add $cmd <url>' to add it." >&2
        return 1
      fi
      ;;
  esac
}
