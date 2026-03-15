# bash-tools

macOS zsh command enhancement tool for quick navigation and opening via path aliases.

## Installation

1. Clone the repository to your local machine:

```bash
git clone https://github.com/leonezhu/bash-tools.git ~/Documents/GitHub/bash-tools
```

2. Add this line to your `~/.zshrc`:

```bash
source ~/Documents/GitHub/bash-tools/init.sh
```

3. Reload your configuration:

```bash
source ~/.zshrc
```

## Commands

### to - Directory Navigation

```bash
to proj                   # Jump to directory by alias
to ~/projects/myapp       # Jump to full path (auto-creates "myapp" alias)
to add proj ~/projects    # Add directory alias (absolute path)
to add config ./.config   # Add relative path alias (works in any directory)
to rm proj                # Remove alias
to ls                     # List all directory aliases
```

#### Relative Path Aliases

Paths starting with `.` or `..` are stored as **relative aliases**, resolved against the current working directory. This allows reusing the same alias across different projects:

```bash
# Add a relative alias once
to add exclude ./.git/info/exclude

# Use it in any git project
cd ~/projects/project-a
to exclude    # Opens ~/projects/project-a/.git/info/exclude

cd ~/projects/project-b
to exclude    # Opens ~/projects/project-b/.git/info/exclude
```

This is especially useful for:
- `.git/info/exclude` - Git exclude file
- `./README.md` - Project readme
- `./package.json` - npm config
- `../` - Parent directory

### dev - Open in VS Code

```bash
dev proj                  # Open directory in VS Code
dev ~/projects/myapp      # Open full path (auto-creates "myapp" alias)
dev add proj ~/projects   # Add directory alias
dev add readme ./README.md  # Add relative path (opens file directly)
dev rm proj               # Remove alias
dev ls                    # List aliases
```

### file - Open in Finder

```bash
file proj                 # Open directory in Finder
file ~/projects/myapp     # Open full path (auto-creates "myapp" alias)
file add proj ~/projects  # Add directory alias
file add exclude ./.git/info/exclude  # Add relative path (reveals file)
file rm proj              # Remove alias
file ls                   # List aliases
```

### web - Open in Browser

```bash
web gh                         # Open URL in browser
web https://github.com/user/repo  # Open full URL (auto-creates "repo" alias)
web https://example.com/page?query=1  # Strips query params, creates "page" alias
web add gh https://github.com  # Add URL alias
web rm gh                      # Remove alias
web ls                         # List all URL aliases
```

### todo - Task Management

Simple task management with priorities and groups.

```bash
todo                           # List pending tasks (todo + doing)
todo ls                        # List all pending tasks
todo ls done                   # List completed tasks
todo ls p1                     # List high priority tasks
todo ls @work                  # List tasks in @work group
todo ls all                    # List all tasks

todo add "Finish report"       # Add task (default: p2)
todo add "Urgent bug" p1       # Add high priority task
todo add "Meeting" p2 @work    # Add task with group

todo doing 1                   # Mark task #1 as in progress
todo done 1                    # Mark task #1 as done
todo todo 1                    # Reset task #1 to todo

todo edit 1 "New content"      # Edit task content
todo rm 1                      # Delete task #1

todo clear                     # Clear all completed tasks
todo clear all                 # Clear all tasks
```

**Priority levels:** `p1` (high), `p2` (medium), `p3` (low)

**Task status:** `todo` → `doing` → `done`

## Auto-Alias Feature

When using full paths or URLs, aliases are automatically created:

| Input                                         | Auto-Alias |
|-----------------------------------------------|------------|
| `to ~/Projects/MyApp`                         | `myapp`    |
| `dev ../ReactApp`                             | `reactapp` |
| `web https://github.com/user/DotFiles`        | `dotfiles` |
| `web https://example.com/page?tab=readme`     | `page`     |

- Aliases are **lowercase** by default
- URL query parameters (`?xxx`) and fragments (`#xxx`) are stripped
- Duplicate aliases are **silently skipped**

## Data Storage

Aliases are stored in `~/.alias_map`:

```text
dir:proj:/Users/xiong/projects
dir:work:/Users/xiong/Documents/work
rel:exclude:./.git/info/exclude
rel:config:./.config
url:gh:https://github.com
url:google:https://google.com
```

- `dir:` - Absolute path aliases
- `rel:` - Relative path aliases (resolved against current directory)
- `url:` - URL aliases

Tasks are stored in `~/.todo_list.json`:

```json
{
  "tasks": [
    {"id": 1, "content": "Finish report", "priority": "p1", "status": "doing", "group": "@work", ...}
  ],
  "nextId": 2
}
```

Customize storage locations via environment variables:

```bash
export ALIAS_MAP_FILE=~/.config/bash-tools/aliases
export TODO_FILE=~/.config/bash-tools/todo.json
```

## Tab Completion

Supports zsh tab completion. Press Tab after typing a command to autocomplete aliases.

## Shared Directory Aliases

`to`, `dev`, and `file` commands share the same directory aliases.

## Development Guide

### Project Structure

```text
bash-tools/
├── init.sh              # Main entry point
├── lib/
│   ├── alias_map.sh     # Core alias management functions
│   ├── to.sh            # to command
│   ├── dev.sh           # dev command
│   ├── file.sh          # file command
│   ├── web.sh           # web command
│   ├── todo.sh          # todo command
│   └── completion.sh    # zsh tab completion
└── README.md
```

### Testing Changes

After modifying any file, reload the scripts:

```bash
source /path/to/bash-tools/init.sh
```

Or restart your shell:

```bash
exec zsh
```

### Adding New Commands

1. Create a new file in `lib/` (e.g., `lib/newcmd.sh`)
2. Source it in `init.sh`
3. Add completion in `lib/completion.sh` if needed

### Debug Mode

To debug issues, you can trace function calls:

```bash
# Enable debug
set -x
to ls
set +x
```
