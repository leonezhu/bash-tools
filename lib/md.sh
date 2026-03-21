#!/bin/bash
# md.sh - View Markdown file in browser with beautiful rendering
#
# Usage:
#   md <alias|path>    - Open markdown file in browser
#   md add <alias> <file> - Add markdown file alias
#   md rm <alias>      - Remove alias
#   md ls              - List all aliases
#   md stop            - Stop the preview server

# Server state file
_MD_SERVER_FILE="${TMPDIR:-/tmp}/md-server-${USER}.pid"

# Main command
md() {
  local cmd="${1:-}"

  case "$cmd" in
    "")
      _md_usage
      return 1
      ;;
    add)
      shift
      _add_alias "dir" "$1" "$2"
      ;;
    rm)
      shift
      _remove_alias "dir" "$1" 2>/dev/null || _remove_alias "rel" "$1"
      ;;
    ls|list)
      echo "Directory aliases (usable by md):"
      _list_aliases "dir"
      _list_aliases "rel"
      ;;
    stop)
      _md_stop_server
      ;;
    help|--help|-h)
      _md_usage
      ;;
    *)
      _md_open "$cmd"
      ;;
  esac
}

# Open markdown file
_md_open() {
  local target="$1"
  local is_full_path=false
  local file_path

  # Check if it's a full path
  if [[ "$target" == /* || "$target" == .* || "$target" == ~* ]]; then
    file_path="${target/#\~/$HOME}"
    is_full_path=true
  else
    # Try to resolve alias
    file_path="$(_resolve_alias "$target")"
    # If alias not found, treat as relative path
    if [[ -z "$file_path" ]]; then
      file_path="$target"
    fi
  fi

  # Check if file exists
  if [[ ! -f "$file_path" ]]; then
    echo "File not found: $file_path" >&2
    return 1
  fi

  # Check if it's a markdown file
  if [[ "${file_path##*.}" != "md" && "${file_path##*.}" != "MD" ]]; then
    echo "Warning: File may not be a markdown file: $file_path" >&2
  fi

  # Auto-add alias for full paths
  if [[ "$is_full_path" == true ]]; then
    _auto_add_dir_alias "$file_path"
  fi

  # Start server and open browser
  _md_serve "$file_path"
}

# Start server and open browser
_md_serve() {
  local md_file="$1"
  local port

  # Stop any existing server first
  _md_stop_server 2>/dev/null

  # Find available port
  port=$(_md_find_port 8765)
  if [[ -z "$port" ]]; then
    echo "No available port found (tried 8765-8774)" >&2
    return 1
  fi

  # Get file info
  local md_filename md_dir
  md_filename=$(basename "$md_file")
  md_dir=$(cd "$(dirname "$md_file")" && pwd)

  # Read markdown content
  local md_content
  md_content=$(cat "$md_file")

  # Create temporary directory
  local temp_dir
  temp_dir=$(mktemp -d)

  # Generate HTML file with embedded markdown content
  _md_generate_html "$md_filename" "$md_content" > "$temp_dir/index.html"

  # Create symlink to markdown file directory for relative images
  ln -s "$md_dir" "$temp_dir/content"

  # Start server in background using nohup
  nohup python3 -m http.server "$port" --directory "$temp_dir" </dev/null &>/dev/null &
  local pid=$!

  # Wait for server to start
  sleep 0.5

  # Check if server started successfully
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Failed to start server" >&2
    rm -rf "$temp_dir"
    return 1
  fi

  # Record server info
  echo "$pid:$port:$temp_dir:$md_file" > "$_MD_SERVER_FILE"

  # Open browser
  open "http://localhost:$port"

  echo "Serving: $md_file"
  echo "URL: http://localhost:$port"
  echo "Run 'md stop' to stop the server"
}

# Generate HTML template with embedded markdown content
_md_generate_html() {
  local md_filename="$1"
  local md_content="$2"

  # Export variables for Python
  export _MD_FILENAME="$md_filename"
  export _MD_CONTENT="$md_content"

  python3 << 'PYEOF'
import json
import os
import re

title = os.environ.get('_MD_FILENAME', 'Untitled')
content = os.environ.get('_MD_CONTENT', '')
content_json = json.dumps(content)

html = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <style>
    :root {{
      --bg-color: #ffffff;
      --text-color: #24292f;
      --code-bg: #f6f8fa;
      --border-color: #d0d7de;
      --link-color: #0969da;
      --quote-color: #57606a;
      --toc-bg: #f6f8fa;
    }}
    @media (prefers-color-scheme: dark) {{
      :root {{
        --bg-color: #0d1117;
        --text-color: #c9d1d9;
        --code-bg: #161b22;
        --border-color: #30363d;
        --link-color: #58a6ff;
        --quote-color: #8b949e;
        --toc-bg: #161b22;
      }}
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: var(--text-color);
      background: var(--bg-color);
      display: flex;
    }}
    /* TOC Sidebar */
    #toc {{
      position: fixed;
      left: 0;
      top: 0;
      width: 260px;
      height: 100vh;
      background: var(--toc-bg);
      border-right: 1px solid var(--border-color);
      padding: 20px 16px;
      overflow-y: auto;
      font-size: 14px;
    }}
    #toc h2 {{
      font-size: 14px;
      font-weight: 600;
      color: var(--text-color);
      margin-bottom: 12px;
      padding-bottom: 8px;
      border-bottom: 1px solid var(--border-color);
    }}
    #toc ul {{
      list-style: none;
      padding: 0;
    }}
    #toc li {{
      margin: 0;
    }}
    #toc a {{
      display: block;
      color: var(--quote-color);
      text-decoration: none;
      padding: 4px 8px;
      border-radius: 4px;
      margin-bottom: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    #toc a:hover {{
      background: var(--border-color);
      color: var(--text-color);
    }}
    #toc a.h1 {{ font-weight: 600; color: var(--text-color); }}
    #toc a.h2 {{ padding-left: 16px; }}
    #toc a.h3 {{ padding-left: 28px; font-size: 13px; }}
    #toc a.h4 {{ padding-left: 40px; font-size: 12px; }}
    /* Main Content */
    #main {{
      margin-left: 260px;
      padding: 40px 40px 40px 60px;
      max-width: 900px;
      flex: 1;
    }}
    pre {{
      background: var(--code-bg);
      padding: 16px;
      border-radius: 6px;
      overflow-x: auto;
      margin: 16px 0;
    }}
    code {{
      font-family: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
      font-size: 85%;
    }}
    p code, li code {{
      background: var(--code-bg);
      padding: 2px 6px;
      border-radius: 4px;
    }}
    pre code {{
      background: none;
      padding: 0;
    }}
    blockquote {{
      border-left: 4px solid var(--border-color);
      padding-left: 16px;
      color: var(--quote-color);
      margin: 16px 0;
    }}
    img {{
      max-width: 100%;
      height: auto;
      border-radius: 6px;
    }}
    table {{
      border-collapse: collapse;
      width: 100%;
      margin: 16px 0;
    }}
    th, td {{
      border: 1px solid var(--border-color);
      padding: 8px 12px;
      text-align: left;
    }}
    th {{
      background: var(--code-bg);
    }}
    h1, h2, h3, h4, h5, h6 {{
      margin-top: 24px;
      margin-bottom: 16px;
      font-weight: 600;
      line-height: 1.25;
      scroll-margin-top: 20px;
    }}
    h1 {{ font-size: 2em; border-bottom: 1px solid var(--border-color); padding-bottom: .3em; }}
    h2 {{ font-size: 1.5em; border-bottom: 1px solid var(--border-color); padding-bottom: .3em; }}
    h3 {{ font-size: 1.25em; }}
    h4 {{ font-size: 1em; }}
    p, ul, ol {{ margin-bottom: 16px; }}
    a {{ color: var(--link-color); text-decoration: none; }}
    a:hover {{ text-decoration: underline; }}
    ul, ol {{ padding-left: 2em; }}
    li + li {{ margin-top: .25em; }}
    hr {{
      border: none;
      border-top: 1px solid var(--border-color);
      margin: 24px 0;
    }}
    .task-list-item {{ list-style: none; margin-left: -1.5em; }}
    .task-list-item input {{ margin-right: 0.5em; }}
    #loading {{
      text-align: center;
      padding: 40px;
      color: var(--quote-color);
    }}
    #fallback {{
      display: none;
      white-space: pre-wrap;
      font-family: monospace;
    }}
    /* Mobile: hide TOC */
    @media (max-width: 900px) {{
      #toc {{ display: none; }}
      #main {{ margin-left: 0; padding: 20px; }}
    }}
  </style>
</head>
<body>
  <nav id="toc">
    <h2>Contents</h2>
    <ul id="toc-list"></ul>
  </nav>
  <main id="main">
    <div id="loading">Rendering markdown...</div>
    <div id="content"></div>
    <pre id="fallback"></pre>
  </main>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script>
    const mdContent = {content_json};

    function slugify(text) {{
      return text.toLowerCase()
        .replace(/[^\\w\\s-]/g, '')
        .replace(/\\s+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '');
    }}

    function generateTOC(html) {{
      const tocList = document.getElementById('toc-list');
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');
      const headings = doc.querySelectorAll('h1, h2, h3, h4');
      const tocHtml = [];

      headings.forEach((h, i) => {{
        const text = h.textContent;
        const id = 'heading-' + i;
        h.id = id;
        tocHtml.push('<li><a href="#' + id + '" class="' + h.tagName.toLowerCase() + '">' + text + '</a></li>');
      }});

      tocList.innerHTML = tocHtml.join('');
      return doc.body.innerHTML;
    }}

    function render() {{
      if (typeof marked !== 'undefined') {{
        document.getElementById('loading').style.display = 'none';
        let html = marked.parse(mdContent).replace(/src="(?!http|\\/)/g, 'src="content/');
        html = generateTOC(html);
        document.getElementById('content').innerHTML = html;
      }} else {{
        setTimeout(function() {{
          if (typeof marked === 'undefined') {{
            document.getElementById('loading').style.display = 'none';
            document.getElementById('fallback').textContent = mdContent;
            document.getElementById('fallback').style.display = 'block';
          }}
        }}, 3000);
      }}
    }}

    if (document.readyState === 'complete') {{
      render();
    }} else {{
      window.addEventListener('load', render);
    }}
  </script>
</body>
</html>'''

print(html)
PYEOF
}

# Find available port
_md_find_port() {
  local start_port="${1:-8765}"
  local port
  for ((port=start_port; port<start_port+10; port++)); do
    if ! lsof -i :$port &>/dev/null; then
      echo "$port"
      return 0
    fi
  done
  return 1
}

# Stop server
_md_stop_server() {
  if [[ ! -f "$_MD_SERVER_FILE" ]]; then
    echo "No server running"
    return 0
  fi

  local pid port temp_dir md_file
  IFS=: read -r pid port temp_dir md_file < "$_MD_SERVER_FILE"

  if [[ -n "$pid" ]] && kill "$pid" 2>/dev/null; then
    echo "Stopped server (PID: $pid, Port: $port)"
  fi

  # Cleanup temp directory
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi

  rm -f "$_MD_SERVER_FILE"
}

# Usage help
_md_usage() {
  cat << 'EOF'
View Markdown file in browser with beautiful rendering

Usage:
  md <alias|path>       - Open markdown file in browser
  md add <alias> <file> - Add markdown file alias
  md rm <alias>         - Remove alias
  md ls                 - List all aliases
  md stop               - Stop the preview server
  md help               - Show this help

Examples:
  md README.md                    # Open local file
  md ~/Documents/notes/test.md    # Open with full path
  md mydoc                        # Open with alias
  md add mydoc ~/docs/mydoc.md    # Add alias
  md stop                         # Stop server

Features:
  - GitHub-style rendering
  - Dark mode support (follows system)
  - Code syntax highlighting
  - Relative image support
EOF
}
