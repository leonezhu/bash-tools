# bash-tools Development Guidelines

## Alias Commands Convention

All alias-based commands (`web`, `to`, `dev`, `file`) MUST support both aliases AND full paths/URLs directly.

### Pattern for Path-Based Commands (`to`, `dev`, `file`)

```bash
# Check if it's a full path (starts with /, ./, ~, or ../)
if [[ "$cmd" == /* || "$cmd" == .* || "$cmd" == ~* ]]; then
  target="${cmd/#\~/$HOME}"
else
  # Try to resolve alias
  target="$(_resolve_alias "$cmd")"
fi
```

### Pattern for URL-Based Commands (`web`)

```bash
# Check if it's a full URL
if [[ "$cmd" == http://* || "$cmd" == https://* ]]; then
  url="$cmd"
else
  # Try to get URL from alias
  url="$(_get_url_alias "$cmd")"
fi
```

### Commands Summary

| Command | Purpose | Supports Alias | Supports Full Path/URL |
|---------|---------|----------------|------------------------|
| `web`   | Open URL in browser / download | Yes | Yes (http/https URLs) |
| `to`    | Navigate to directory | Yes | Yes (/, ./, ~, ../) |
| `dev`   | Open in VS Code | Yes | Yes (/, ./, ~, ../) |
| `file`  | Open in Finder | Yes | Yes (/, ./, ~, ../) |

### When Adding New Alias Commands

1. Always support both aliases AND direct values (paths/URLs)
2. Use the detection patterns above
3. Update the help text to reflect both usage modes
4. Update this documentation table
