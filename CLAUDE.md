# bash-tools Development Guidelines

## Alias Commands Convention

All alias-based commands (`web`, `to`, `dev`, `file`, `sync`) MUST support both aliases AND full paths/URLs directly.

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

### Auto-Alias Feature

When using full paths/URLs, the system automatically creates aliases:

- **URLs**: Extracts last path segment (lowercase), strips query params
  - `https://github.com/user/DotFiles?tab=readme` → `dotfiles`
- **Paths**: Extracts last path segment (lowercase)
  - `~/Projects/MyApp` → `myapp`

Aliases are skipped silently if they already exist.

### Commands Summary

| Command | Purpose              | Alias | Full Path/URL    | Auto-Alias |
|---------|----------------------|-------|------------------|------------|
| `web`   | Open URL             | Yes   | http/https URLs  | Yes        |
| `to`    | Navigate to dir      | Yes   | /, ./, ~, ../    | Yes        |
| `dev`   | Open in VS Code      | Yes   | /, ./, ~, ../    | Yes        |
| `file`  | Open in Finder       | Yes   | /, ./, ~, ../    | Yes        |
| `sync`  | Git add/commit/push  | Yes   | /, ./, ~, ../    | Yes        |

### When Adding New Alias Commands

1. Always support both aliases AND direct values (paths/URLs)
2. Use the detection patterns above
3. Call `_auto_add_url_alias` or `_auto_add_dir_alias` for full paths/URLs
4. Update the help text to reflect both usage modes
5. Update this documentation table
