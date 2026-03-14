# bash-tools

macOS zsh command enhancement tool for quick navigation and opening via path aliases.

## Installation

Add this line to your `~/.zshrc`:

```bash
source /path/to/bash-tools/init.sh
```

Then reload your configuration:

```bash
source ~/.zshrc
```

## Commands

### to - Directory Navigation

```bash
to proj                   # Jump to directory by alias
to add proj ~/projects    # Add directory alias
to rm proj                # Remove alias
to ls                     # List all directory aliases
```

### dev - Open in VS Code

```bash
dev proj                  # Open directory in VS Code
dev add proj ~/projects   # Add directory alias
dev rm proj               # Remove alias
dev ls                    # List aliases
```

### file - Open in Finder

```bash
file proj                 # Open directory in Finder
file add proj ~/projects  # Add directory alias
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
url:gh:https://github.com
url:google:https://google.com
```

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
