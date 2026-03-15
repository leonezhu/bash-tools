#!/bin/bash
# todo.sh - Simple task management command
#
# Usage:
#   todo                  - List all pending tasks (todo + doing)
#   todo ls [filter]      - List all tasks (optional: done, p1, p2, p3, @group)
#   todo add "task" [p] [@group] - Add a new task
#   todo done <id>        - Mark task as done
#   todo doing <id>       - Mark task as doing
#   todo rm <id>          - Delete a task
#   todo edit <id> "new"  - Edit task content
#   todo clear [done|all] - Clear completed or all tasks
#   todo help             - Show help

# Config file path
TODO_FILE="${TODO_FILE:-$HOME/.todo_list.json}"

# Ensure jq is available
_todo_check_jq() {
  if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required but not installed." >&2
    echo "Install with: brew install jq" >&2
    return 1
  fi
  return 0
}

# Make URLs clickable using OSC 8 hyperlink protocol
# Supported by iTerm2, macOS Terminal, Kitty, etc.
_todo_make_links() {
  local text="$1"
  # Match http:// or https:// URLs and make them clickable
  echo "$text" | sed -E 's|(https?://[^[:space:]]+)|\x1b]8;;\1\x1b\\\1\x1b]8;;\x1b\\|g'
}

# Initialize todo file if not exists
_todo_init() {
  if [[ ! -f "$TODO_FILE" ]]; then
    echo '{"tasks": [], "nextId": 1}' > "$TODO_FILE"
  fi
}

# Load tasks from JSON file
_todo_load() {
  _todo_init
  cat "$TODO_FILE"
}

# Save tasks to JSON file
_todo_save() {
  local data="$1"
  echo "$data" > "$TODO_FILE"
}

# Get current timestamp
_todo_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Add a new task
_todo_add() {
  local content="$1"
  local priority="${2:-p2}"
  local group="${3:-}"

  if [[ -z "$content" ]]; then
    echo "Error: Task content is required" >&2
    return 1
  fi

  # Validate priority
  if [[ ! "$priority" =~ ^p[123]$ ]]; then
    # Check if priority is actually a group
    if [[ "$priority" == @* ]]; then
      group="$priority"
      priority="p2"
    else
      echo "Error: Invalid priority. Use p1, p2, or p3" >&2
      return 1
    fi
  fi

  local data
  data=$(_todo_load)

  local next_id
  next_id=$(echo "$data" | jq -r '.nextId')

  local timestamp
  timestamp=$(_todo_timestamp)

  # Build task JSON
  local task
  if [[ -n "$group" ]]; then
    task=$(jq -n \
      --argjson id "$next_id" \
      --arg content "$content" \
      --arg priority "$priority" \
      --arg group "$group" \
      --arg created "$timestamp" \
      --arg updated "$timestamp" \
      '{id: $id, content: $content, priority: $priority, status: "todo", group: $group, created: $created, updated: $updated}')
  else
    task=$(jq -n \
      --argjson id "$next_id" \
      --arg content "$content" \
      --arg priority "$priority" \
      --arg created "$timestamp" \
      --arg updated "$timestamp" \
      '{id: $id, content: $content, priority: $priority, status: "todo", group: null, created: $created, updated: $updated}')
  fi

  # Add task and increment nextId
  data=$(echo "$data" | jq --argjson task "$task" '.tasks += [$task] | .nextId += 1')
  _todo_save "$data"

  echo "Added task #$next_id: $content"
}

# List tasks with optional filter
_todo_list() {
  local filter="${1:-}"
  local data
  data=$(_todo_load)

  local tasks
  case "$filter" in
    "")
      # Default: show todo and doing
      tasks=$(echo "$data" | jq '.tasks | map(select(.status == "todo" or .status == "doing")) | sort_by(.priority, .id)')
      ;;
    done)
      tasks=$(echo "$data" | jq '.tasks | map(select(.status == "done")) | sort_by(.updated) | reverse')
      ;;
    p1|p2|p3)
      tasks=$(echo "$data" | jq --arg p "$filter" '.tasks | map(select(.priority == $p)) | sort_by(.status, .id)')
      ;;
    @*)
      local group="${filter:1}"
      tasks=$(echo "$data" | jq --arg g "$group" '.tasks | map(select(.group == $g)) | sort_by(.priority, .id)')
      ;;
    all)
      tasks=$(echo "$data" | jq '.tasks | sort_by(.priority, .id)')
      ;;
    *)
      echo "Unknown filter: $filter" >&2
      return 1
      ;;
  esac

  local count
  count=$(echo "$tasks" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No tasks found."
    return 0
  fi

  # Print header
  printf "  %-4s %-3s %-8s %-10s %s\n" "ID" "PR" "STATUS" "GROUP" "CONTENT"
  echo "  -----------------------------------------------------------"

  # Print tasks
  echo "$tasks" | jq -r '.[] | [.id, .priority, .status, (.group // "-"), .content] | @tsv' | \
    while IFS=$'\t' read -r tid prio tstat tgrp tcontent; do
      printf "  %-4s %-3s %-8s %-10s %s\n" "$tid" "$prio" "$tstat" "$tgrp" "$(_todo_make_links "$tcontent")"
    done
}

# List pending tasks (default view)
_todo_pending() {
  local data
  data=$(_todo_load)

  local tasks
  tasks=$(echo "$data" | jq '.tasks | map(select(.status == "todo" or .status == "doing")) | sort_by(.priority, .id)')

  local count
  count=$(echo "$tasks" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No pending tasks."
    return 0
  fi

  # Print compact view
  echo "$tasks" | jq -r '.[] | "  [\(.priority)] \(if .status == "doing" then "▶" else "○" end) \(.content)\(if .group then " \(.group)" else "" end)"' | \
    while IFS= read -r line; do
      echo "$(_todo_make_links "$line")"
    done
}

# Update task status
_todo_status() {
  local id="$1"
  local tstatus="$2"

  if [[ -z "$id" ]]; then
    echo "Error: Task ID is required" >&2
    return 1
  fi

  if [[ ! "$tstatus" =~ ^(todo|doing|done)$ ]]; then
    echo "Error: Invalid status. Use todo, doing, or done" >&2
    return 1
  fi

  local data
  data=$(_todo_load)

  # Check if task exists
  local exists
  exists=$(echo "$data" | jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length')

  if [[ "$exists" -eq 0 ]]; then
    echo "Error: Task #$id not found" >&2
    return 1
  fi

  local timestamp
  timestamp=$(_todo_timestamp)

  # Update task status
  data=$(echo "$data" | jq --argjson id "$id" --arg tstatus "$tstatus" --arg updated "$timestamp" \
    '.tasks = [.tasks[] | if .id == $id then .status = $tstatus | .updated = $updated else . end]')

  _todo_save "$data"

  local status_icon
  case "$tstatus" in
    done)  status_icon="✓" ;;
    doing) status_icon="▶" ;;
    *)     status_icon="○" ;;
  esac

  echo "$status_icon Task #$id marked as $tstatus"
}

# Delete a task
_todo_rm() {
  local id="$1"

  if [[ -z "$id" ]]; then
    echo "Error: Task ID is required" >&2
    return 1
  fi

  local data
  data=$(_todo_load)

  # Check if task exists
  local exists
  exists=$(echo "$data" | jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length')

  if [[ "$exists" -eq 0 ]]; then
    echo "Error: Task #$id not found" >&2
    return 1
  fi

  # Remove task
  data=$(echo "$data" | jq --argjson id "$id" '.tasks = [.tasks[] | select(.id != $id)]')
  _todo_save "$data"

  echo "✗ Task #$id removed"
}

# Edit task content
_todo_edit() {
  local id="$1"
  local content="$2"

  if [[ -z "$id" ]]; then
    echo "Error: Task ID is required" >&2
    return 1
  fi

  if [[ -z "$content" ]]; then
    echo "Error: New content is required" >&2
    return 1
  fi

  local data
  data=$(_todo_load)

  # Check if task exists
  local exists
  exists=$(echo "$data" | jq --argjson id "$id" '.tasks | map(select(.id == $id)) | length')

  if [[ "$exists" -eq 0 ]]; then
    echo "Error: Task #$id not found" >&2
    return 1
  fi

  local timestamp
  timestamp=$(_todo_timestamp)

  # Update task content
  data=$(echo "$data" | jq --argjson id "$id" --arg content "$content" --arg updated "$timestamp" \
    '.tasks = [.tasks[] | if .id == $id then .content = $content | .updated = $updated else . end]')

  _todo_save "$data"

  echo "✎ Task #$id updated"
}

# Clear tasks
_todo_clear() {
  local scope="${1:-done}"

  local data
  data=$(_todo_load)

  local count
  case "$scope" in
    done)
      count=$(echo "$data" | jq '.tasks | map(select(.status == "done")) | length')
      if [[ "$count" -eq 0 ]]; then
        echo "No completed tasks to clear."
        return 0
      fi
      data=$(echo "$data" | jq '.tasks = [.tasks[] | select(.status != "done")]')
      echo "Cleared $count completed task(s)."
      ;;
    all)
      count=$(echo "$data" | jq '.tasks | length')
      if [[ "$count" -eq 0 ]]; then
        echo "No tasks to clear."
        return 0
      fi
      data=$(echo "$data" | jq '.tasks = []')
      echo "Cleared all $count task(s)."
      ;;
    *)
      echo "Error: Unknown scope. Use 'done' or 'all'" >&2
      return 1
      ;;
  esac

  _todo_save "$data"
}

# Show help
_todo_help() {
  echo "Todo - Simple task management"
  echo ""
  echo "Usage:"
  echo "  todo                          List pending tasks (todo + doing)"
  echo "  todo ls [filter]              List tasks"
  echo "                                Filters: done, p1, p2, p3, @group, all"
  echo ""
  echo "  todo add <content> [priority] [@group]"
  echo "                                Add a new task"
  echo "                                Priority: p1 (high), p2 (medium), p3 (low)"
  echo "                                Default: p2"
  echo ""
  echo "  todo done <id>                Mark task as done"
  echo "  todo doing <id>               Mark task as in progress"
  echo "  todo rm <id>                  Delete a task"
  echo "  todo edit <id> <content>      Edit task content"
  echo ""
  echo "  todo clear [done|all]         Clear completed or all tasks"
  echo "  todo help                     Show this help"
  echo ""
  echo "Examples:"
  echo "  todo add \"Finish the report\" p1 @work"
  echo "  todo add \"Buy groceries\" p3"
  echo "  todo ls p1                    List all p1 tasks"
  echo "  todo ls @work                 List tasks in @work group"
  echo "  todo doing 1"
  echo "  todo done 1"
}

# Main todo command
todo() {
  # Check for jq
  _todo_check_jq || return 1

  local cmd="${1:-}"
  shift 2>/dev/null || true

  case "$cmd" in
    "")
      _todo_pending
      ;;
    ls|list)
      _todo_list "$@"
      ;;
    add)
      local content="${1:-}"
      local priority="${2:-}"
      local group="${3:-}"

      # Parse arguments - support flexible ordering
      for arg in "$@"; do
        if [[ "$arg" =~ ^p[123]$ ]]; then
          priority="$arg"
        elif [[ "$arg" == @* ]]; then
          group="$arg"
        elif [[ -z "$content" ]]; then
          content="$arg"
        fi
      done

      _todo_add "$content" "$priority" "$group"
      ;;
    done)
      _todo_status "$1" "done"
      ;;
    doing)
      _todo_status "$1" "doing"
      ;;
    todo)
      _todo_status "$1" "todo"
      ;;
    rm|remove|delete)
      _todo_rm "$1"
      ;;
    edit)
      _todo_edit "$1" "$2"
      ;;
    clear)
      _todo_clear "$1"
      ;;
    help|--help|-h)
      _todo_help
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Use 'todo help' for usage information." >&2
      return 1
      ;;
  esac
}
