#!/bin/bash
# run.sh - Execute saved command aliases
#
# Usage:
#   run <alias> [args...]    - Execute command by alias with optional arguments
#   run add <alias> <cmd>    - Add command alias
#   run rm <alias>           - Remove command alias
#   run ls                   - List all command aliases
#   run edit <alias>         - Edit command alias in editor
#
# Examples:
#   run add deploy "kubectl rollout status deployment/myapp"
#   run deploy
#   run add build "npm run build"
#   run build --production

run() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      echo "Usage: run <alias> [args...] | run add <alias> <cmd> | run rm <alias> | run ls | run edit <alias>" >&2
      return 1
      ;;
    add)
      if [[ -z "$2" || -z "$3" ]]; then
        echo "Usage: run add <alias> <command>" >&2
        return 1
      fi
      _add_alias "cmd" "$2" "$3"
      ;;
    rm)
      _remove_alias "cmd" "$2"
      ;;
    ls|list)
      _list_aliases "cmd"
      ;;
    edit)
      if [[ -z "$2" ]]; then
        echo "Usage: run edit <alias>" >&2
        return 1
      fi
      local current_cmd
      current_cmd=$(_get_cmd_alias "$2")
      if [[ -z "$current_cmd" ]]; then
        echo "Command alias '$2' not found." >&2
        return 1
      fi
      # Create temp file with current command
      local tmp_file
      tmp_file=$(mktemp)
      echo "$current_cmd" > "$tmp_file"
      # Open in editor
      ${EDITOR:-vi} "$tmp_file"
      # Read edited command
      local new_cmd
      new_cmd=$(cat "$tmp_file")
      rm -f "$tmp_file"
      # Update if changed
      if [[ "$new_cmd" != "$current_cmd" && -n "$new_cmd" ]]; then
        _remove_alias "cmd" "$2" silently
        _add_alias "cmd" "$2" "$new_cmd"
      else
        echo "No changes made."
      fi
      ;;
    help|--help|-h)
      echo "Execute saved command aliases"
      echo ""
      echo "Usage:"
      echo "  run <alias> [args...]     - Execute command by alias"
      echo "  run add <alias> <cmd>     - Add command alias"
      echo "  run rm <alias>            - Remove command alias"
      echo "  run ls                    - List all command aliases"
      echo "  run edit <alias>          - Edit command in \$EDITOR"
      echo ""
      echo "Examples:"
      echo "  run add deploy 'kubectl rollout status deployment/myapp'"
      echo "  run deploy"
      echo "  run add build 'npm run build'"
      echo "  run build --production"
      ;;
    *)
      # Get command by alias
      local saved_cmd
      saved_cmd=$(_get_cmd_alias "$cmd")

      if [[ -z "$saved_cmd" ]]; then
        echo "Unknown command alias: $cmd" >&2
        echo "Use 'run add $cmd <command>' to add it." >&2
        return 1
      fi

      # Shift off the alias and pass remaining arguments
      shift

      # Execute the command with any additional arguments
      # Using eval to properly handle quoted strings in the saved command
      eval "$saved_cmd \"\$@\""
      ;;
  esac
}
