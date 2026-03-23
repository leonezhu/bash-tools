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
| `md`    | View markdown in browser | Yes | /, ./, ~, ../  | Yes        |
| `path`  | Copy path to clipboard | Yes | /, ./, ~, ../  | Yes        |
| `run`   | Execute saved cmd    | Yes   | N/A              | N/A        |
| `ob`    | Obsidian search/open | N/A   | N/A              | N/A        |

### Obsidian Command (`ob`)

```bash
ob s <query>    # Search notes, auto-open if single result
ob <file>       # Open file directly
```

Examples:
- `ob s 网页访问方式评估` - Search notes, shows list if multiple results
- `ob s file:网页访问` - Search with file filter for precise match
- `ob References/note.md` - Open specific file

### Search Subcommand (`s`)

Directory-based commands (`to`, `dev`, `file`, `md`, `path`) support a `s` subcommand for fuzzy file search and execution:

```bash
to s [alias|path] [pattern]    # Search and execute files in directory
dev s [alias|path] [pattern]   # Search and execute files in directory
file s [alias|path] [pattern]  # Search and execute files in directory
md s [alias|path] [pattern]    # Search markdown files only
path s [alias|path] [pattern]  # Search and copy file path to clipboard
```

Examples:
- `file s .` - Search files in current directory
- `dev s myproject api` - Search files with "api" pattern in myproject alias
- `md s . readme` - Search markdown files with "readme" pattern
- `path s . config` - Search files and copy selected path to clipboard

### When Adding New Alias Commands

1. Always support both aliases AND direct values (paths/URLs)
2. Use the detection patterns above
3. Call `_auto_add_url_alias` or `_auto_add_dir_alias` for full paths/URLs
4. Update the help text to reflect both usage modes
5. Update this documentation table
