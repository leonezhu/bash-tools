#!/bin/bash
# alias_map.sh - Core alias management functions
#
# Data format:
#   dir:alias:/path/to/directory  (absolute path)
#   rel:alias:./relative/path     (relative to current directory)
#   url:alias:https://example.com

# Data file path
ALIAS_MAP_FILE="${ALIAS_MAP_FILE:-$HOME/.alias_map}"

# Ensure data file exists
_ensure_alias_file() {
  if [[ ! -f "$ALIAS_MAP_FILE" ]]; then
    touch "$ALIAS_MAP_FILE"
  fi
}

# Get directory path by alias (absolute path)
# Usage: _get_dir_alias <alias>
# Returns: path if exists, empty otherwise
_get_dir_alias() {
  local alias="$1"
  if [[ -z "$alias" ]]; then
    return 1
  fi
  _ensure_alias_file
  local line t a value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == dir:${alias}:* ]] || continue
    # Parse: dir:alias:/path/to/dir
    t="${line%%:*}"
    line="${line#*:}"
    a="${line%%:*}"
    value="${line#*:}"
    echo "$value"
    return 0
  done < "$ALIAS_MAP_FILE"
  return 1
}

# Get relative path by alias
# Usage: _get_rel_alias <alias>
# Returns: relative path if exists, empty otherwise
_get_rel_alias() {
  local alias="$1"
  if [[ -z "$alias" ]]; then
    return 1
  fi
  _ensure_alias_file
  local line t a value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == rel:${alias}:* ]] || continue
    # Parse: rel:alias:./relative/path
    t="${line%%:*}"
    line="${line#*:}"
    a="${line%%:*}"
    value="${line#*:}"
    echo "$value"
    return 0
  done < "$ALIAS_MAP_FILE"
  return 1
}

# Resolve alias to actual path (checks dir first, then rel)
# Usage: _resolve_alias <alias>
# Returns: resolved path if exists, empty otherwise
_resolve_alias() {
  local alias="$1"
  if [[ -z "$alias" ]]; then
    return 1
  fi

  # First check for absolute path alias
  local result
  result=$(_get_dir_alias "$alias")
  if [[ -n "$result" ]]; then
    echo "$result"
    return 0
  fi

  # Then check for relative path alias
  result=$(_get_rel_alias "$alias")
  if [[ -n "$result" ]]; then
    # Resolve relative to current directory
    echo "$PWD/$result"
    return 0
  fi

  return 1
}

# Get command by alias
# Usage: _get_cmd_alias <alias>
# Returns: command if exists, empty otherwise
_get_cmd_alias() {
  local alias="$1"
  if [[ -z "$alias" ]]; then
    return 1
  fi
  _ensure_alias_file
  local line t a value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == cmd:${alias}:* ]] || continue
    # Parse: cmd:alias:command string
    t="${line%%:*}"
    line="${line#*:}"
    a="${line%%:*}"
    value="${line#*:}"
    echo "$value"
    return 0
  done < "$ALIAS_MAP_FILE"
  return 1
}

# Get URL by alias
# Usage: _get_url_alias <alias>
# Returns: URL if exists, empty otherwise
_get_url_alias() {
  local alias="$1"
  if [[ -z "$alias" ]]; then
    return 1
  fi
  _ensure_alias_file
  local line t a value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == url:${alias}:* ]] || continue
    # Parse: url:alias:https://...
    t="${line%%:*}"
    line="${line#*:}"
    a="${line%%:*}"
    value="${line#*:}"
    echo "$value"
    return 0
  done < "$ALIAS_MAP_FILE"
  return 1
}

# Check if alias exists
# Usage: _alias_exists <type> <alias>
# Returns: 0 if exists, 1 if not
_alias_exists() {
  local type="$1"
  local alias="$2"
  _ensure_alias_file
  grep -q "^${type}:${alias}:" "$ALIAS_MAP_FILE" 2>/dev/null
}

# Add alias (prompts for confirmation if already exists)
# Usage: _add_alias <type> <alias> <value>
#   For dir type: paths starting with . or .. are stored as rel type
# Returns: 0 on success, 1 on failure
_add_alias() {
  local type="$1"
  local alias="$2"
  local value="$3"

  if [[ -z "$alias" || -z "$value" ]]; then
    echo "Usage: add <alias> <value>" >&2
    return 1
  fi

  # For dir type, check if it should be stored as relative
  if [[ "$type" == "dir" ]]; then
    # Paths starting with . or .. are stored as relative (rel type)
    if [[ "$value" == .* || "$value" == ..* ]]; then
      type="rel"
    elif [[ "$value" == ~* ]]; then
      # Expand ~ to $HOME
      value="${value/#\~/$HOME}"
    elif [[ "$value" != /* ]]; then
      # Other relative paths (without ./) are converted to absolute
      value="$(cd "$(dirname "$value")" 2>/dev/null && pwd)/$(basename "$value")"
    fi
  fi

  _ensure_alias_file

  # Check if already exists (check both dir and rel for the alias)
  local existing_type=""
  if _alias_exists "dir" "$alias"; then
    existing_type="dir"
  elif _alias_exists "rel" "$alias"; then
    existing_type="rel"
  elif _alias_exists "$type" "$alias"; then
    existing_type="$type"
  fi

  if [[ -n "$existing_type" ]]; then
    local current_value
    current_value=$(_get_${existing_type}_alias "$alias")
    echo "Alias '$alias' already exists: $current_value"
    read -k 1 "?Overwrite? [y/N] "
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Cancelled."
      return 1
    fi
    # Remove old entry
    _remove_alias "$existing_type" "$alias" silently
  fi

  # Add new entry
  echo "${type}:${alias}:${value}" >> "$ALIAS_MAP_FILE"
  echo "Added ${type} alias: $alias -> $value"
}

# Remove alias
# Usage: _remove_alias <type> <alias> [silently]
# Returns: 0 on success, 1 on failure
_remove_alias() {
  local type="$1"
  local alias="$2"
  local silently="$3"

  if [[ -z "$alias" ]]; then
    echo "Usage: rm <alias>" >&2
    return 1
  fi

  _ensure_alias_file

  if ! _alias_exists "$type" "$alias"; then
    [[ "$silently" != "silently" ]] && echo "Alias '$alias' not found." >&2
    return 1
  fi

  # Create temp file and remove matching line
  local temp_file
  temp_file=$(mktemp)
  grep -v "^${type}:${alias}:" "$ALIAS_MAP_FILE" > "$temp_file" 2>/dev/null || true
  mv "$temp_file" "$ALIAS_MAP_FILE"

  [[ "$silently" != "silently" ]] && echo "Removed ${type} alias: $alias"
  return 0
}

# Extract alias name from URL (last path segment, cleaned, lowercase)
# Usage: _extract_url_alias <url>
# Returns: suggested alias name (lowercase)
_extract_url_alias() {
  local url="$1"
  local path

  # Remove protocol
  url="${url#http://}"
  url="${url#https://}"

  # Remove query parameters and fragments
  url="${url%%\?*}"
  url="${url%%#*}"

  # Remove trailing slash
  url="${url%/}"

  # Get the last path segment (or full host if no path)
  if [[ "$url" == */* ]]; then
    # Has path, get last segment
    path="${url##*/}"
  else
    # No path, use the host/domain
    path="$url"
  fi

  # Clean up domain: remove www. prefix and common TLDs
  path="${path#www.}"
  path="${path%.com}"
  path="${path%.net}"
  path="${path%.org}"
  path="${path%.io}"
  path="${path%.dev}"
  path="${path%.app}"

  # Return lowercase alias (compatible with bash and zsh)
  /usr/bin/tr '[:upper:]' '[:lower:]' <<< "$path"
}

# Extract alias name from path (last path segment, lowercase)
# Usage: _extract_path_alias <path>
# Returns: suggested alias name (lowercase)
_extract_path_alias() {
  local path="$1"

  # Remove trailing slash
  path="${path%/}"

  # Get the last path segment
  path="${path##*/}"

  # Return lowercase alias (compatible with bash and zsh)
  /usr/bin/tr '[:upper:]' '[:lower:]' <<< "$path"
}

# Auto-add URL alias (silent, skips if exists)
# Usage: _auto_add_url_alias <url>
# Returns: 0 if added, 1 if skipped (already exists)
_auto_add_url_alias() {
  local url="$1"
  local alias
  local clean_url

  if [[ -z "$url" ]]; then
    return 1
  fi

  # Clean URL: remove query params and fragments
  clean_url="${url%%\?*}"
  clean_url="${clean_url%%#*}"
  clean_url="${clean_url%/}"

  alias=$(_extract_url_alias "$url")

  if [[ -z "$alias" ]]; then
    return 1
  fi

  # Check if already exists
  if _alias_exists "url" "$alias"; then
    return 1
  fi

  # Add silently
  _ensure_alias_file
  echo "url:${alias}:${clean_url}" >> "$ALIAS_MAP_FILE"
  echo "Auto-added URL alias: $alias -> $clean_url"
  return 0
}

# Auto-add directory alias (silent, skips if exists)
# Usage: _auto_add_dir_alias <path>
# Returns: 0 if added, 1 if skipped (already exists or invalid)
_auto_add_dir_alias() {
  local path="$1"
  local alias

  if [[ -z "$path" ]]; then
    return 1
  fi

  # Skip special paths that shouldn't be aliased
  # ., .., ./, ../, and similar relative paths have no persistent meaning
  case "$path" in
    .|..|./|../) return 1 ;;
  esac

  # Expand ~
  path="${path/#\~/$HOME}"

  alias=$(_extract_path_alias "$path")

  if [[ -z "$alias" ]]; then
    return 1
  fi

  # Determine type (dir or rel)
  local type="dir"
  local stored_path="$path"
  if [[ "$path" == .* || "$path" == ..* ]]; then
    type="rel"
    stored_path="$path"
  elif [[ "$path" != /* ]]; then
    # Convert to absolute path
    stored_path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")"
  fi

  # Check if already exists (check both dir and rel)
  if _alias_exists "dir" "$alias" || _alias_exists "rel" "$alias"; then
    return 1
  fi

  # Add silently
  _ensure_alias_file
  echo "${type}:${alias}:${stored_path}" >> "$ALIAS_MAP_FILE"
  echo "Auto-added ${type} alias: $alias -> $stored_path"
  return 0
}

# List all aliases of specified type
# Usage: _list_aliases <type>
#   For "dir" type, also shows "rel" aliases
_list_aliases() {
  local type="$1"
  _ensure_alias_file

  local type_label
  case "$type" in
    dir) type_label="Directory" ;;
    rel) type_label="Relative" ;;
    url) type_label="URL" ;;
    cmd) type_label="Command" ;;
    *)   type_label="$type" ;;
  esac

  local entries
  entries=$(grep "^${type}:" "$ALIAS_MAP_FILE" 2>/dev/null)

  if [[ -z "$entries" ]]; then
    echo "No ${type} aliases defined."
    return 0
  fi

  echo "${type_label} aliases:"
  echo "$entries" | while IFS=: read -r t alias value; do
    printf "  %-15s -> %s\n" "$alias" "$value"
  done
}
