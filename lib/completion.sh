#!/bin/bash
# completion.sh - zsh tab completion

# Enable fuzzy matching for completions
# - m:{a-z}={A-Z}: case-insensitive matching
# - r:|[._-]=*: partial matching after separators (., _, -)
# - l:|=* r:|=*: substring matching (match anywhere in the word)
if [[ -n "$ZSH_VERSION" ]]; then
  zstyle ':completion:*' matcher-list \
    'm:{a-z}={A-Z}' \
    'r:|[._-]=* r:|=*' \
    'l:|=* r:|=*'
fi

# Directory alias completion function (for to/dev/file)
_dir_alias_completion() {
  local -a aliases subcommands
  local context state line

  _arguments -C \
    '1: :->cmds' \
    '*::arg:->args'

  # Subcommands
  subcommands=(
    'add:Add a new directory alias'
    'rm:Remove a directory alias'
    'ls:List all directory aliases'
    'help:Show help'
  )

  # Read directory aliases - format: "name:description"
  if [[ -f "$ALIAS_MAP_FILE" ]]; then
    local alias_part path_part
    while IFS=: read -r type alias_part path_part; do
      [[ "$type" == "dir" ]] && aliases+=("${alias_part}:${path_part}")
    done < "$ALIAS_MAP_FILE"
  fi

  case $state in
    cmds)
      _describe 'subcommand' subcommands
      _describe 'alias' aliases
      ;;
    args)
      case $line[1] in
        rm)
          _describe 'alias' aliases
          ;;
        add)
          if (( CURRENT == 2 )); then
            _message "alias name"
          else
            _files -/
          fi
          ;;
      esac
      ;;
  esac
}

# URL alias completion function (for web)
_url_alias_completion() {
  local -a aliases subcommands
  local context state line

  _arguments -C \
    '1: :->cmds' \
    '*::arg:->args'

  # Subcommands
  subcommands=(
    'add:Add a new URL alias'
    'rm:Remove a URL alias'
    'ls:List all URL aliases'
    'help:Show help'
  )

  # Read URL aliases - format: "name:description"
  if [[ -f "$ALIAS_MAP_FILE" ]]; then
    local alias_part url_part
    while IFS=: read -r type alias_part url_part; do
      [[ "$type" == "url" ]] && aliases+=("${alias_part}:${url_part}")
    done < "$ALIAS_MAP_FILE"
  fi

  case $state in
    cmds)
      _describe 'subcommand' subcommands
      _describe 'alias' aliases
      ;;
    args)
      case $line[1] in
        rm)
          _describe 'alias' aliases
          ;;
        add)
          _message "alias name"
          ;;
      esac
      ;;
  esac
}

# Todo command completion function
_todo_completion() {
  local -a subcommands priorities statuses tasks
  local context state line

  _arguments -C \
    '1: :->cmds' \
    '*::arg:->args'

  # Subcommands
  subcommands=(
    'add:Add a new task'
    'ls:List tasks'
    'done:Mark task as done'
    'doing:Mark task as in progress'
    'rm:Delete a task'
    'edit:Edit task content'
    'clear:Clear tasks'
    'help:Show help'
  )

  # Priorities
  priorities=(
    'p1:High priority'
    'p2:Medium priority (default)'
    'p3:Low priority'
  )

  # Statuses
  statuses=(
    'done:Completed tasks'
    'p1:High priority tasks'
    'p2:Medium priority tasks'
    'p3:Low priority tasks'
    'all:All tasks'
  )

  # Load tasks for ID completion
  if [[ -f "$HOME/.todo_list.json" ]]; then
    local id content
    while IFS=$'\t' read -r id content; do
      [[ -n "$id" ]] && tasks+=("$id:$content")
    done < <(jq -r '.tasks[] | "\(.id)\t\(.content)"' "$HOME/.todo_list.json" 2>/dev/null)
  fi

  case $state in
    cmds)
      _describe 'subcommand' subcommands
      ;;
    args)
      case $line[1] in
        ls|list)
          _describe 'filter' statuses
          ;;
        add)
          if (( CURRENT == 2 )); then
            _message "task content"
          else
            _describe 'priority' priorities
          fi
          ;;
        done|doing|todo|rm|remove)
          _describe 'task' tasks
          ;;
        edit)
          if (( CURRENT == 2 )); then
            _describe 'task' tasks
          else
            _message "new content"
          fi
          ;;
        clear)
          local -a clear_opts
          clear_opts=(
            'done:Clear completed tasks (default)'
            'all:Clear all tasks'
          )
          _describe 'scope' clear_opts
          ;;
      esac
      ;;
  esac
}

# Sync command completion function
_sync_completion() {
  local -a aliases actions subcommands
  local context state line

  _arguments -C \
    '1: :->cmds' \
    '2: :->actions'

  # Subcommands
  subcommands=(
    'help:Show help'
  )

  # Actions for sync command
  actions=(
    'status:Show git status'
    'pull:Pull latest changes from remote'
    'push:Add, commit, and push (default)'
  )

  # Read directory aliases - format: "name:description"
  if [[ -f "$ALIAS_MAP_FILE" ]]; then
    local alias_part path_part
    while IFS=: read -r type alias_part path_part; do
      [[ "$type" == "dir" || "$type" == "rel" ]] && aliases+=("${alias_part}:${path_part}")
    done < "$ALIAS_MAP_FILE"
  fi

  case $state in
    cmds)
      _describe 'subcommand' subcommands
      _describe 'alias' aliases
      ;;
    actions)
      _describe 'action' actions
      ;;
  esac
}

# MD command completion function
_md_completion() {
  local -a aliases subcommands
  local context state line

  _arguments -C \
    '1: :->cmds' \
    '*::arg:->args'

  # Subcommands
  subcommands=(
    'add:Add a new markdown file alias'
    'rm:Remove an alias'
    'ls:List all aliases'
    'stop:Stop the preview server'
    'help:Show help'
  )

  # Read directory aliases - md uses dir and rel type aliases
  if [[ -f "$ALIAS_MAP_FILE" ]]; then
    local alias_part path_part
    while IFS=: read -r type alias_part path_part; do
      [[ "$type" == "dir" || "$type" == "rel" ]] && aliases+=("${alias_part}:${path_part}")
    done < "$ALIAS_MAP_FILE"
  fi

  case $state in
    cmds)
      _describe 'subcommand' subcommands
      _describe 'alias' aliases
      _files -g '*.md'
      ;;
    args)
      case $line[1] in
        rm)
          _describe 'alias' aliases
          ;;
        add)
          if (( CURRENT == 2 )); then
            _message "alias name"
          else
            _files -g '*.md'
          fi
          ;;
      esac
      ;;
  esac
}

# Register completion functions (only when compdef is available)
if type compdef &>/dev/null; then
  compdef _dir_alias_completion to
  compdef _dir_alias_completion dev
  compdef _dir_alias_completion file
  compdef _url_alias_completion web
  # Use -p to override existing completion for sync (which is a builtin)
  compdef -p _sync_completion sync 2>/dev/null || true
  # Register todo completion
  compdef _todo_completion todo 2>/dev/null || true
  # Register md completion
  compdef _md_completion md
fi
