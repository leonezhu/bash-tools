# bash-tools

macOS zsh command enhancement tool for quick navigation and opening via path aliases.

## Installation

1. Clone the repository to your local machine:

```bash
git clone https://github.com/yourusername/bash-tools.git ~/Documents/GitHub/bash-tools
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
dev add proj ~/projects   # Add directory alias
dev add readme ./README.md  # Add relative path (opens file directly)
dev rm proj               # Remove alias
dev ls                    # List aliases
```

### file - Open in Finder

```bash
file proj                 # Open directory in Finder
file add proj ~/projects  # Add directory alias
file add exclude ./.git/info/exclude  # Add relative path (reveals file)
file rm proj              # Remove alias
file ls                   # List aliases
```

### web - Open in Browser

```bash
web gh                         # Open URL in browser
web add gh https://github.com  # Add URL alias
web rm gh                      # Remove alias
web ls                         # List all URL aliases
```

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

Customize storage location via environment variable:

```bash
export ALIAS_MAP_FILE=~/.config/bash-tools/aliases
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
