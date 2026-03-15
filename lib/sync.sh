#!/bin/bash
# sync.sh - Git sync command for committing and pushing changes
#
# Usage:
#   sync <alias|path> - Sync git repo by alias or full path (add, commit, push)
#   sync <alias|path> status - Show git status of the repo
#   sync <alias|path> pull - Pull latest changes from remote

sync() {
  local cmd="${1:-}"
  local action="${2:-push}"

  case "$cmd" in
    "")
      echo "Usage: sync <alias|path> [status|pull|push]" >&2
      echo "       sync ls" >&2
      echo "       sync help" >&2
      return 1
      ;;
    ls|list)
      _list_aliases "dir"
      _list_aliases "rel"
      ;;
    help|--help|-h)
      echo "Git sync command - commit and push changes"
      echo ""
      echo "Usage:"
      echo "  sync <alias|path>        - Add all changes, commit, and push"
      echo "  sync <alias|path> status - Show git status"
      echo "  sync <alias|path> pull   - Pull latest changes from remote"
      echo "  sync ls                  - List all directory aliases"
      echo ""
      echo "The command supports both aliases and full paths:"
      echo "  sync myproject           - Use alias 'myproject'"
      echo "  sync ~/Projects/app      - Use full path"
      echo "  sync ./mydir             - Use relative path"
      ;;
    *)
      local target
      local is_full_path=false

      # Check if it's a full path (starts with /, ./, ~, or ../)
      if [[ "$cmd" == /* || "$cmd" == .* || "$cmd" == ~* ]]; then
        target="${cmd/#\~/$HOME}"
        is_full_path=true
      else
        # Try to resolve alias
        target="$(_resolve_alias "$cmd")"
      fi

      if [[ -z "$target" ]]; then
        echo "Unknown alias: $cmd" >&2
        echo "Use 'to add $cmd <path>' to add it." >&2
        return 1
      fi

      # Auto-add alias for full paths
      if [[ "$is_full_path" == true ]]; then
        _auto_add_dir_alias "$cmd"
      fi

      if [[ ! -e "$target" ]]; then
        echo "Path does not exist: $target" >&2
        return 1
      fi

      # If target is a file, use its parent directory
      if [[ -f "$target" ]]; then
        target="$(dirname "$target")"
      fi

      # Check if it's a git repository
      if [[ ! -d "$target/.git" ]]; then
        echo "Not a git repository: $target" >&2
        return 1
      fi

      # Execute the action
      case "$action" in
        status)
          echo "=== Git status for: $target ==="
          (cd "$target" && git status)
          ;;
        pull)
          echo "=== Pulling changes for: $target ==="
          (cd "$target" && git pull)
          ;;
        push|"")
          echo "=== Syncing: $target ==="

          # Check if there are any changes
          local has_changes
          has_changes=$(cd "$target" && git status --porcelain)

          if [[ -z "$has_changes" ]]; then
            echo "No changes to commit. Checking for remote updates..."
            (cd "$target" && git push)
            return $?
          fi

          # Show what will be committed
          echo ""
          echo "Changes to be synced:"
          echo "$has_changes"
          echo ""

          # Get commit message
          local commit_msg
          read "commit_msg?Enter commit message (or press Enter for auto): "

          if [[ -z "$commit_msg" ]]; then
            # Generate auto commit message with timestamp
            commit_msg="Auto sync: $(date '+%Y-%m-%d %H:%M:%S')"
          fi

          # Add, commit, and push
          (cd "$target" && git add -A && git commit -m "$commit_msg" && git push)

          if [[ $? -eq 0 ]]; then
            echo ""
            echo "✓ Successfully synced: $target"
          else
            echo ""
            echo "✗ Sync failed for: $target" >&2
            return 1
          fi
          ;;
        *)
          echo "Unknown action: $action" >&2
          echo "Valid actions: status, pull, push (default)" >&2
          return 1
          ;;
      esac
      ;;
  esac
}
