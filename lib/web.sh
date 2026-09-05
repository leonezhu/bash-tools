#!/bin/bash
# web.sh - Open URL in browser or download to file
#
# Usage:
#   web <alias>              - Open URL in default browser by alias
#   web <url>                - Open full URL in default browser
#   web <alias|url> to <path> - Download URL to specified path
#   web repo [alias|path] [subpath] - Open GitHub page of a git repository
#   web add <alias> <url>    - Add URL alias
#   web rm <alias>           - Remove URL alias
#   web ls                   - List all URL aliases

# Convert a git remote URL to a web URL
# Usage: _remote_to_web_url <remote_url>
#   git@github.com:user/repo.git       -> https://github.com/user/repo
#   ssh://git@github.com/user/repo.git -> https://github.com/user/repo
#   http://github.com/user/repo.git    -> https://github.com/user/repo
#   https://github.com/user/repo.git   -> https://github.com/user/repo
_remote_to_web_url() {
  local url="$1"
  url="${url%.git}"
  case "$url" in
    ssh://git@*)
      url="https://${url#ssh://git@}"
      ;;
    http://*)
      url="https://${url#http://}"
      ;;
    *@*:*)
      # scp-like syntax: user@host:path
      local user_host="${url%%:*}"
      user_host="${user_host##*@}"   # strip user prefix, keep host only
      local path="${url#*:}"
      url="https://${user_host}/${path}"
      ;;
  esac
  echo "$url"
}

# Open the GitHub (or any git host) web page of a repository
# Usage: _web_repo [alias|path] [subpath]
#   _web_repo               - Current directory's repo
#   _web_repo notes         - Repo by directory alias
#   _web_repo ~/some/repo   - Repo by full path
#   _web_repo . src/lib     - Open subpath (dir -> tree, file -> blob) on current branch
_web_repo() {
  local target="${1:-.}"
  local subpath="${2:-}"

  # Resolve alias or path (supports aliases AND full paths, per convention)
  local dir=""
  if [[ "$target" == /* || "$target" == ~* || "$target" == .* ]]; then
    dir="${target/#\~/$HOME}"
  else
    dir="$(_resolve_alias "$target")"
    if [[ -z "$dir" ]] && [[ -e "$target" ]]; then
      dir="$target"
    fi
  fi

  if [[ -z "$dir" || ! -e "$dir" ]]; then
    echo "Unknown alias or path: $target" >&2
    return 1
  fi

  # If target is a file, use its parent directory
  [[ -f "$dir" ]] && dir="$(dirname "$dir")"

  # Convert to absolute path
  dir="$(cd "$dir" 2>/dev/null && pwd)" || {
    echo "Cannot access directory: $dir" >&2
    return 1
  }

  # Find git toplevel (searches upward like git does)
  local toplevel
  toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not a git repository: $dir" >&2
    return 1
  }

  # Get origin remote URL
  local remote_url
  remote_url="$(git -C "$dir" remote get-url origin 2>/dev/null)" || {
    echo "No 'origin' remote configured in: $toplevel" >&2
    return 1
  }

  # Build web URL
  local url
  url="$(_remote_to_web_url "$remote_url")"

  # Optional subpath -> open under current branch (file -> blob, dir -> tree)
  if [[ -n "$subpath" ]]; then
    local branch
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
      branch="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
    fi
    local clean="${subpath#/}"
    local kind="tree"
    [[ -f "$toplevel/$clean" ]] && kind="blob"
    url="${url}/${kind}/${branch}/${clean}"
  fi

  # Auto-add URL alias (consistent with conventions; skip when subpath is set
  # to avoid junk aliases like "lib" or "readme.md")
  if [[ -z "$subpath" ]]; then
    _auto_add_url_alias "$url"
  fi

  open "$url"
  echo "Opened: $url"
}

web() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: web <alias|url> [to <path>] | web repo [alias|path] [subpath] | web add <alias> <url> | web rm <alias> | web ls" >&2
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
    repo)
      _web_repo "${2:-}" "${3:-}"
      ;;
    help|--help|-h)
      echo "Open URL in browser or download to file"
      echo ""
      echo "Usage:"
      echo "  web <alias>              - Open URL in default browser"
      echo "  web <url>                - Open full URL in default browser"
      echo "  web <alias|url> to <path> - Download URL to specified path"
      echo "  web repo [alias|path] [subpath] - Open repo's GitHub page (subpath: file->blob, dir->tree)"
      echo "  web add <alias> <url>    - Add URL alias"
      echo "  web rm <alias>           - Remove URL alias"
      echo "  web ls                   - List all URL aliases"
      ;;
    *)
      # Check if it's a full URL
      local url=""
      local is_full_url=false
      if [[ "$cmd" == http://* || "$cmd" == https://* ]]; then
        url="$cmd"
        is_full_url=true
      else
        # Try to get URL from alias
        url="$(_get_url_alias "$cmd")"
      fi

      if [[ -z "$url" ]]; then
        echo "Unknown alias: $cmd" >&2
        echo "Use 'web add $cmd <url>' to add it." >&2
        return 1
      fi

      # Auto-add alias for full URLs
      if [[ "$is_full_url" == true ]]; then
        _auto_add_url_alias "$url"
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
        echo "Opened: $url"
      fi
      ;;
  esac
}
