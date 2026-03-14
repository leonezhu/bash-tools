#!/bin/bash
# completion.sh - zsh tab completion

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

# Register completion functions (only when compdef is available)
if type compdef &>/dev/null; then
  compdef _dir_alias_completion to
  compdef _dir_alias_completion dev
  compdef _dir_alias_completion file
  compdef _url_alias_completion web
fi
