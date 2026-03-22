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
    s|search)
      local search_dir search_pattern
      # Smart argument parsing:
      # - No args: search current dir, no pattern
      # - One arg starting with path prefix: search that dir, no pattern
      # - One arg not a path: search current dir with that pattern
      # - Two args: first is dir, second is pattern
      if [[ -z "${2:-}" ]]; then
        search_dir="."
        search_pattern=""
      elif [[ -z "${3:-}" ]]; then
        # Only one argument provided
        if [[ "$2" == /* || "$2" == .* || "$2" == ~* ]]; then
          # Looks like a path
          search_dir="$2"
          search_pattern=""
        else
          # Try to resolve as alias first
          local resolved
          resolved="$(_resolve_alias "$2")"
          if [[ -n "$resolved" ]]; then
            search_dir="$resolved"
            search_pattern=""
          else
            # Not an alias, treat as pattern
            search_dir="."
            search_pattern="$2"
          fi
        fi
      else
        # Two arguments: dir and pattern
        search_dir="$2"
        search_pattern="$3"
      fi
      # Normalize path
      search_dir="${search_dir/#\~/$HOME}"
      _search_and_execute "$search_dir" "$search_pattern" "*.md" "_md_open"
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

  # Convert relative path to absolute path
  if [[ "$file_path" != /* ]]; then
    file_path="$(cd "$(dirname "$file_path")" 2>/dev/null && pwd)/$(basename "$file_path")"
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
      --meta-bg: #f6f8fa;
      --meta-label: #57606a;
      --tag-bg: #ddf4ff;
      --tag-color: #0969da;
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
        --meta-bg: #161b22;
        --meta-label: #8b949e;
        --tag-bg: #1f3d5c;
        --tag-color: #58a6ff;
      }}
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: var(--text-color);
      background: var(--bg-color);
    }}
    /* Layout wrapper for centering */
    .layout {{
      display: flex;
      justify-content: center;
      min-height: 100vh;
    }}
    /* TOC Sidebar - positioned next to centered main */
    #toc {{
      position: fixed;
      left: calc(50% - 460px - 220px);
      top: 0;
      width: 220px;
      height: 100vh;
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
    #toc a.active {{
      background: var(--link-color);
      color: #ffffff;
      font-weight: 500;
    }}
    #toc a.h1 {{ font-weight: 600; color: var(--text-color); }}
    #toc a.h2 {{ padding-left: 16px; }}
    #toc a.h3 {{ padding-left: 28px; font-size: 13px; }}
    #toc a.h4 {{ padding-left: 40px; font-size: 12px; }}
    html {{
      scroll-behavior: smooth;
    }}
    /* Main Content - centered */
    #main {{
      padding: 40px 60px;
      max-width: 900px;
      width: 900px;
      min-height: 100vh;
    }}
    /* Frontmatter/Metadata Styles */
    .frontmatter {{
      background: var(--meta-bg);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      padding: 16px 20px;
      margin-bottom: 24px;
      font-size: 14px;
    }}
    .frontmatter-title {{
      font-size: 12px;
      font-weight: 600;
      color: var(--meta-label);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 6px;
    }}
    .frontmatter-title::before {{
      content: "";
      display: inline-block;
      width: 14px;
      height: 14px;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%238b949e' stroke-width='2'%3E%3Cpath d='M4 7V4h16v3M9 20h6M12 4v16'/%3E%3C/svg%3E");
      background-size: contain;
      background-repeat: no-repeat;
    }}
    .frontmatter-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 12px;
    }}
    .meta-item {{
      display: flex;
      flex-direction: column;
      gap: 2px;
    }}
    .meta-label {{
      font-size: 12px;
      color: var(--meta-label);
      font-weight: 500;
    }}
    .meta-value {{
      color: var(--text-color);
    }}
    .meta-value.date {{
      font-variant-numeric: tabular-nums;
    }}
    .meta-tags {{
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }}
    .meta-tag {{
      display: inline-block;
      background: var(--tag-bg);
      color: var(--tag-color);
      padding: 2px 10px;
      border-radius: 16px;
      font-size: 12px;
    }}
    .meta-boolean {{
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }}
    .meta-boolean.true {{ color: #1a7f37; }}
    .meta-boolean.false {{ color: #cf222e; }}
    .meta-alias {{
      background: var(--code-bg);
      padding: 2px 8px;
      border-radius: 4px;
      font-family: 'SF Mono', monospace;
      font-size: 13px;
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
    @media (max-width: 1200px) {{
      #toc {{ display: none; }}
      #main {{ width: 100%; max-width: 100%; padding: 20px; }}
      .frontmatter-grid {{ grid-template-columns: 1fr; }}
    }}
  </style>
</head>
<body>
  <nav id="toc">
    <ul id="toc-list"></ul>
  </nav>
  <div class="layout">
  <main id="main">
    <div id="loading">Rendering markdown...</div>
    <div id="frontmatter" class="frontmatter" style="display:none;">
      <div class="frontmatter-title">Properties</div>
      <div id="frontmatter-content" class="frontmatter-grid"></div>
    </div>
    <div id="content"></div>
    <pre id="fallback"></pre>
  </main>
  </div>
  <link rel="preconnect" href="https://unpkg.com">
  <script src="https://unpkg.com/marked@12/marked.min.js"></script>
  <script src="https://unpkg.com/js-yaml@4/dist/js-yaml.min.js"></script>
  <script>
    const mdContent = {content_json};

    // Parse frontmatter from markdown
    function parseFrontmatter(content) {{
      const fmRegex = /^---\\s*\\n([\\s\\S]*?)\\n---\\s*\\n/;
      const match = content.match(fmRegex);
      if (!match) return {{ frontmatter: null, content: content }};

      const yamlStr = match[1];
      const remainingContent = content.slice(match[0].length);

      try {{
        const frontmatter = jsyaml.load(yamlStr);
        return {{ frontmatter, content: remainingContent }};
      }} catch (e) {{
        console.warn('Failed to parse frontmatter:', e);
        return {{ frontmatter: null, content: content }};
      }}
    }}

    // Format frontmatter value for display
    function formatValue(key, value) {{
      if (value === null || value === undefined) {{
        return '<span class="meta-value">-</span>';
      }}

      // Handle tags specially
      const tagKeys = ['tags', 'tag', 'keywords', 'categories'];
      if (tagKeys.includes(key.toLowerCase())) {{
        const tags = Array.isArray(value) ? value : [value];
        const tagsHtml = tags.map(t => `<span class="meta-tag">${{escapeHtml(String(t))}}</span>`).join('');
        return `<div class="meta-tags">${{tagsHtml}}</div>`;
      }}

      // Handle boolean
      if (typeof value === 'boolean') {{
        const icon = value ? '✓' : '✗';
        const cls = value ? 'true' : 'false';
        return `<span class="meta-boolean ${{cls}}">${{icon}} ${{value}}</span>`;
      }}

      // Handle array
      if (Array.isArray(value)) {{
        if (value.length === 0) return '<span class="meta-value">[]</span>';
        // Check if it's an alias format (common in Obsidian)
        if (value.every(v => typeof v === 'string')) {{
          return `<div class="meta-tags">${{value.map(v => `<span class="meta-alias">${{escapeHtml(v)}}</span>`).join('')}}</div>`;
        }}
        return `<span class="meta-value">${{escapeHtml(value.join(', '))}}</span>`;
      }}

      // Handle date-like strings
      if (typeof value === 'string') {{
        const datePattern = /^\\d{{4}}-\\d{{2}}-\\d{{2}}/;
        if (datePattern.test(value)) {{
          return `<span class="meta-value date">${{escapeHtml(value)}}</span>`;
        }}
        // Handle aliases (Obsidian [[]] format)
        if (value.startsWith('[[') && value.endsWith(']]')) {{
          const link = value.slice(2, -2);
          return `<span class="meta-alias">${{escapeHtml(link)}}</span>`;
        }}
      }}

      return `<span class="meta-value">${{escapeHtml(String(value))}}</span>`;
    }}

    function escapeHtml(text) {{
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }}

    // Render frontmatter
    function renderFrontmatter(frontmatter) {{
      if (!frontmatter || Object.keys(frontmatter).length === 0) {{
        return;
      }}

      const container = document.getElementById('frontmatter-content');
      let html = '';

      // Define common keys order
      const priorityKeys = ['title', 'date', 'created', 'updated', 'tags', 'author', 'status', 'type', 'aliases'];
      const allKeys = Object.keys(frontmatter);

      // Sort: priority keys first, then alphabetical
      const sortedKeys = [
        ...priorityKeys.filter(k => k in frontmatter),
        ...allKeys.filter(k => !priorityKeys.includes(k)).sort()
      ];

      for (const key of sortedKeys) {{
        const value = frontmatter[key];
        html += `
          <div class="meta-item">
            <span class="meta-label">${{escapeHtml(key)}}</span>
            ${{formatValue(key, value)}}
          </div>
        `;
      }}

      container.innerHTML = html;
      document.getElementById('frontmatter').style.display = 'block';
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
        h.setAttribute('data-heading', 'true');
        tocHtml.push('<li><a href="#' + id + '" class="toc-link ' + h.tagName.toLowerCase() + '" data-target="' + id + '">' + text + '</a></li>');
      }});

      tocList.innerHTML = tocHtml.join('');

      // Setup scroll spy
      setupScrollSpy();

      return doc.body.innerHTML;
    }}

    function setupScrollSpy() {{
      const tocLinks = document.querySelectorAll('.toc-link');
      const headings = document.querySelectorAll('[data-heading="true"]');

      if (headings.length === 0) return;

      // Remove all active states
      function clearActive() {{
        tocLinks.forEach(link => link.classList.remove('active'));
      }}

      // Set active state for a link
      function setActive(id) {{
        clearActive();
        const link = document.querySelector('.toc-link[data-target="' + id + '"]');
        if (link) {{
          link.classList.add('active');
          // Scroll TOC to show active item
          link.scrollIntoView({{ behavior: 'smooth', block: 'nearest' }});
        }}
      }}

      // Find current active heading based on scroll position
      function updateActiveHeading() {{
        let currentHeading = null;
        let minTop = Infinity;

        headings.forEach(h => {{
          const rect = h.getBoundingClientRect();
          // Find heading that is at or above 120px from viewport top
          if (rect.top <= 120 && rect.top < minTop) {{
            minTop = rect.top;
            currentHeading = h;
          }}
        }});

        if (currentHeading) {{
          setActive(currentHeading.id);
        }}
      }}

      // Throttle scroll events
      let ticking = false;
      window.addEventListener('scroll', () => {{
        if (!ticking) {{
          window.requestAnimationFrame(() => {{
            updateActiveHeading();
            ticking = false;
          }});
          ticking = true;
        }}
      }});

      // Initial update
      updateActiveHeading();

      // Also handle click events for immediate feedback
      tocLinks.forEach(link => {{
        link.addEventListener('click', (e) => {{
          const targetId = link.getAttribute('data-target');
          setActive(targetId);
        }});
      }});
    }}

    function render() {{
      document.getElementById('loading').style.display = 'none';

      if (typeof marked === 'undefined') {{
        setTimeout(function() {{
          if (typeof marked === 'undefined') {{
            document.getElementById('fallback').textContent = mdContent;
            document.getElementById('fallback').style.display = 'block';
          }}
        }}, 3000);
        return;
      }}

      // Parse frontmatter
      const {{ frontmatter, content: bodyContent }} = parseFrontmatter(mdContent);

      // Render frontmatter if exists
      if (typeof jsyaml !== 'undefined') {{
        renderFrontmatter(frontmatter);
      }}

      // Render markdown body
      let html = marked.parse(bodyContent).replace(/src="(?!http|\\/)/g, 'src="content/');
      html = generateTOC(html);
      document.getElementById('content').innerHTML = html;
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
  md s [pattern]        - Search markdown files in current dir
  md s [alias|path] [pattern] - Search markdown files in specified dir
  md add <alias> <file> - Add markdown file alias
  md rm <alias>         - Remove alias
  md ls                 - List all aliases
  md stop               - Stop the preview server
  md help               - Show this help

Examples:
  md README.md                    # Open local file
  md ~/Documents/notes/test.md    # Open with full path
  md mydoc                        # Open with alias
  md s au                         # Search markdown files with 'au' pattern
  md s . api                      # Search markdown files containing 'api'
  md s myproject readme           # Search in alias 'myproject'
  md add mydoc ~/docs/mydoc.md    # Add alias
  md stop                         # Stop server

Features:
  - GitHub-style rendering
  - Dark mode support (follows system)
  - Code syntax highlighting
  - Relative image support
  - Obsidian frontmatter support (YAML metadata)
EOF
}
