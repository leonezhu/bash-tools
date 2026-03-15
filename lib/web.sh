#!/bin/bash
# web.sh - Open URL in browser or download to file
#
# Usage:
#   web <alias>              - Open URL in default browser by alias
#   web <url>                - Open full URL in default browser
#   web <alias|url> to <path> - Download URL to specified path
#   web add <alias> <url>    - Add URL alias
#   web rm <alias>           - Remove URL alias
#   web ls                   - List all URL aliases

web() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: web <alias|url> [to <path>] | web add <alias> <url> | web rm <alias> | web ls" >&2
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
      echo "Open URL in browser or download to file"
      echo ""
      echo "Usage:"
      echo "  web <alias>              - Open URL in default browser"
      echo "  web <url>                - Open full URL in default browser"
      echo "  web <alias|url> to <path> - Download URL to specified path"
      echo "  web add <alias> <url>    - Add URL alias"
      echo "  web rm <alias>           - Remove URL alias"
      echo "  web ls                   - List all URL aliases"
      ;;
    *)
      # Check if it's a full URL
      local url=""
      if [[ "$cmd" == http://* || "$cmd" == https://* ]]; then
        url="$cmd"
      else
        # Try to get URL from alias
        url="$(_get_url_alias "$cmd")"
      fi

      if [[ -z "$url" ]]; then
        echo "Unknown alias: $cmd" >&2
        echo "Use 'web add $cmd <url>' to add it." >&2
        return 1
      fi

      # Check for "to <path>" syntax
      if [[ "$2" == "to" && -n "$3" ]]; then
        local dest_path="$3"
        # Expand ~ in path
        dest_path="${dest_path/#\~/$HOME}"
        echo "Downloading $url to $dest_path..."
        curl -L -o "$dest_path" "$url"
      else
        open "$url"
      fi
      ;;
  esac
}
