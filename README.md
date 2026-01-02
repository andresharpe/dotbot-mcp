# dotbot-mcp - Project-Native MCP Server Framework

A pure PowerShell framework for building project-native MCP (Model Context Protocol) servers with zero external dependencies. Create intelligent, file-based tools that live in your repository and make your AI development partner smarter, more efficient, and context-aware.

## Vision

**Your AI agent should understand your project like a team member does.**

dotbot-mcp enables you to build MCP servers that:
- **Live in your repository** - Everything your AI needs is version-controlled alongside your code
- **Zero dependencies** - Pure PowerShell, works anywhere PowerShell 7+ runs
- **File-based by default** - Transparent, human-readable, git-friendly state and configuration
- **Self-documenting** - Tools are discoverable with clear schemas and metadata
- **Extensible** - Add new tools without touching server code

### Real-World Use Cases

Build MCP tools for:
- **Project management**: Structure exploration, dependency graphs, backlog management
- **Lifecycle operations**: Start/stop/restart services, deployment workflows, health checks
- **Specification management**: Requirements tracking, spec generation, design documents
- **Task planning**: Break down work, track progress, manage dependencies
- **Development workflows**: Prompt generation, code review automation, testing orchestration
- **State tracking**: Sprint progress, feature flags, release readiness

### Philosophy

**Idiomatic approach**: Everything your AI partner needs should be in the repository - specs, state files, metadata, tool definitions. This makes exploration transparent and development traceable. Tools can use databases or external services when needed, but the default is plain files that both humans and AI can read.

**Save time and tokens**: Context-aware tools reduce the need for repeated explanations, large file reads, and trial-and-error. Your AI agent gets accurate, structured information on the first try.

## This Repository

dotbot-mcp itself is a working example - a date/time tool server demonstrating the modular architecture. Use it as a template for building your own project-native MCP servers.

### Features

- **Modular tool discovery**: Drop tools in folders, they're auto-loaded
- **Convention over configuration**: No manual registration, just follow the structure
- **Pure PowerShell**: No npm, pip, or cargo - just pwsh
- **Cross-platform**: Windows, Linux, macOS with PowerShell 7+
- **Standard MCP**: JSON-RPC over stdio, works with Claude Desktop, Warp, etc.

## Included Tools

This repository includes 8 working tools as examples:

### Date/Time Tools
1. **get_current_datetime** - Current time with timezone/format support
2. **add_to_date** - Date arithmetic (add/subtract time units)
3. **get_date_difference** - Calculate time spans between dates
4. **format_date** - Convert between date formats
5. **parse_timestamp** - Unix timestamp conversion
6. **get_timezones** - List available system timezones

### Location Tools (requires API key)
7. **get_public_holidays** - Check if a date is a public holiday using place names or coordinates
8. **get_current_time_at** - Get the current local time at any location worldwide

See `examples.ps1` for usage patterns, or explore `.bot/mcp/tools/` to see how each tool is implemented.

## Project Structure

```
.
├── .env.example             # API keys template (copy to .env)
├── .gitignore               # Includes .env files
└── .bot/mcp/
    ├── dotbot-mcp.ps1           # Main server entry point
    ├── dotbot-mcp-helpers.ps1   # Shared helper functions
    ├── metadata.yaml            # Server metadata
    ├── README-NEWTOOL.md        # Guide for adding new tools
    └── tools/                   # Auto-discovered tools
        ├── get-current-datetime/
        ├── add-to-date/
        ├── get-date-difference/
        ├── format-date/
        ├── parse-timestamp/
        ├── get-timezones/
        └── get-public-holidays/  # Requires Google Maps API key
```

Each tool is self-contained with:
- `script.ps1` - Implementation
- `metadata.yaml` - Schema and description
- `test.ps1` - Tool-specific tests

## Installation

### For Claude Desktop

1. Locate your Claude Desktop config file:
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Linux: `~/.config/Claude/claude_desktop_config.json`

2. Add this server configuration:
```json
{
  "mcpServers": {
    "dotbot-mcp": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "/absolute/path/to/dotbot-mcp/.bot/mcp/dotbot-mcp.ps1"
      ]
    }
  }
}
```

**Note:** Replace the file path with your actual installation path. On Windows, use double backslashes: `C:\\Users\\...`

3. Restart Claude Desktop

### API Keys Configuration

Some tools require API keys to function (e.g., `get_public_holidays` needs Google Maps API).

1. Copy the example environment file:
```powershell
cp .env.example .env
```

2. Edit `.env` and add your API keys:
```bash
GOOGLE_MAPS_API_KEY=your_actual_api_key_here
```

3. Get your Google Maps API key:
   - Visit [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable the **Geocoding API** in the API Library
   - Create credentials (API Key) under "Credentials"

**Note:** The `.env` file is git-ignored for security. Never commit API keys to version control.

### Standalone Testing

Test the server directly:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1
```

Then send JSON-RPC requests via stdin:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_current_datetime","arguments":{"utc":true}}}
```

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get up and running in 5 minutes
- **[WARP.md](WARP.md)** - Architecture deep-dive and development guide
- **[.bot/mcp/README-NEWTOOL.md](.bot/mcp/README-NEWTOOL.md)** - Step-by-step guide to adding new tools
- **[examples.ps1](examples.ps1)** - Example tool usage patterns

## Building Your Own Tools

Adding a tool is as simple as creating a folder:

```
.bot/mcp/tools/your-tool/
├── script.ps1       # Implement Invoke-YourTool function
├── metadata.yaml    # Name, description, JSON Schema
└── test.ps1         # Tool tests
```

The server automatically discovers and loads it. No registration, no configuration.

See [.bot/mcp/README-NEWTOOL.md](.bot/mcp/README-NEWTOOL.md) for the complete guide.

## Requirements

- PowerShell 7.0 or later (cross-platform)
- No external dependencies or packages

## License

MIT
