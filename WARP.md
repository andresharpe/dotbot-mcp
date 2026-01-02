# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

dotbot-mcp is a pure PowerShell implementation of an MCP (Model Context Protocol) server that provides date/time manipulation tools via JSON-RPC over stdio. It features a modular architecture where tools are auto-discovered and dynamically loaded from individual directories. Designed for PowerShell 7+ and integrates with Claude Desktop and other MCP clients.

## Common Commands

### Testing
```powershell
# View example usage patterns
.\examples.ps1

# Run an individual tool test (requires server process)
$process = Start-Process pwsh -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', '.bot\mcp\dotbot-mcp.ps1'
) -NoNewWindow -PassThru -RedirectStandardInput stdin.txt -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt

. .bot\mcp\tools\get-current-datetime\test.ps1 -Process $process
$process | Stop-Process
```

### Development
```powershell
# Start server manually (for debugging)
pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1

# View server metadata
Get-Content .bot/mcp/metadata.yaml

# List all tools
Get-ChildItem .bot/mcp/tools -Directory
```

### Manual Testing with JSON-RPC
When server is running, send requests via stdin:
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_current_datetime","arguments":{"utc":true}}}
```

## Architecture

### Modular Design
The server uses a convention-based, modular architecture:
- **Entry Point**: `.bot/mcp/dotbot-mcp.ps1` - Main server with JSON-RPC event loop
- **Helpers**: `.bot/mcp/dotbot-mcp-helpers.ps1` - Shared utilities
- **Metadata**: `.bot/mcp/metadata.yaml` - Server configuration (protocol version, capabilities, server info)
- **Tools Directory**: `.bot/mcp/tools/` - Auto-discovered tool modules

### Directory Structure
```
.bot/mcp/
├── dotbot-mcp.ps1           # Main server entry point
├── dotbot-mcp-helpers.ps1   # Shared helper functions
├── metadata.yaml            # Server metadata
├── README-NEWTOOL.md        # Guide for adding new tools
└── tools/                   # Auto-discovered tools
    ├── get-current-datetime/
    │   ├── script.ps1       # Tool implementation
    │   ├── metadata.yaml    # Tool schema
    │   └── test.ps1         # Tool tests
    ├── add-to-date/
    ├── get-date-difference/
    ├── format-date/
    ├── parse-timestamp/
    └── get-timezones/
```

### Core Components

#### JSON-RPC Transport (`dotbot-mcp.ps1`)
The main loop handles stdio-based JSON-RPC communication:
- Reads newline-delimited JSON from stdin
- Deserializes to hashtables using `-AsHashtable` for easier manipulation
- Routes requests to appropriate handlers
- Writes responses to stdout with proper flushing
- Errors go to stderr, responses to stdout

#### Tool Discovery (startup)
1. Scans `.bot/mcp/tools/` directory
2. For each subdirectory:
   - Loads `metadata.yaml` (name, description, inputSchema)
   - Dot-sources `script.ps1` (makes functions available)
   - Registers tool in `$tools` hashtable
3. No explicit configuration needed - purely convention-based

#### MCP Protocol Handlers
Three primary handlers implement the MCP protocol:
- **`Invoke-Initialize`**: Returns server capabilities and metadata from `metadata.yaml`
- **`Invoke-ListTools`**: Dynamically builds tool list from loaded tools
- **`Invoke-CallTool`**: Dispatches to tool functions (converts snake_case names to PascalCase)

#### Tool Implementations
Each tool directory contains:
- **script.ps1**: Implements `Invoke-<ToolName>` function that receives `[hashtable]$Arguments`
- **metadata.yaml**: Defines tool name (snake_case), description, and JSON Schema for inputs
- **test.ps1**: Receives `$Process` parameter and uses `Send-McpRequest` helper

All tools use .NET's `[DateTime]` and `[TimeZoneInfo]` classes for deterministic, cross-platform date handling.

#### Helper Functions (`dotbot-mcp-helpers.ps1`)
- `Write-JsonRpcResponse`: Serializes and flushes JSON responses
- `Write-JsonRpcError`: Formats JSON-RPC error objects
- `Get-DateFromString`: Centralized date parsing with optional format strings

### Testing Architecture

Each tool has its own `test.ps1` file that:
- Receives a running server process as a parameter
- Uses `Send-McpRequest` helper to communicate via stdin/stdout
- Validates tool-specific behavior
- Can be run individually or as part of a test suite

## Development Guidelines

### Date Handling
- Always use `[System.Globalization.CultureInfo]::InvariantCulture` for parsing/formatting to ensure consistent behavior across locales
- Prefer ISO 8601 format (`'o'`) as default output
- Use `[DateTimeOffset]` for Unix timestamp conversions to handle timezone offsets properly

### Error Handling
- Use JSON-RPC error codes: -32601 (method not found), -32603 (internal error)
- Return descriptive error messages in the `message` field
- Log errors to stderr (visible in Claude Desktop logs)
- Always include the request `id` in error responses

### Adding New Tools
See `.bot/mcp/README-NEWTOOL.md` for complete guide. Quick summary:

1. Create directory: `.bot/mcp/tools/your-tool-name/`
2. Create three files:
   - `script.ps1`: Implement `Invoke-YourToolName` function
   - `metadata.yaml`: Define name (snake_case), description, inputSchema (JSON Schema)
   - `test.ps1`: Write tests using `Send-McpRequest` helper
3. Server automatically discovers and loads the tool on startup

No changes needed to main server files - purely additive.

### PowerShell Conventions
- Use approved verbs (Invoke-, Get-, etc.)
- Declare `[CmdletBinding()]` for advanced function features
- Use `$ErrorActionPreference = 'Stop'` to convert non-terminating errors
- Flush stdout after every response: `[Console]::Out.Flush()`

## MCP Configuration

To integrate with Claude Desktop, users must add this server to `claude_desktop_config.json`:

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Linux:** `~/.config/Claude/claude_desktop_config.json`

The server uses stdio transport, so the configuration specifies `pwsh` as the command with arguments to execute `.bot/mcp/dotbot-mcp.ps1`. See `mcp-config.json` in the project root for a reference configuration.

## Cross-Platform Considerations

- Use PowerShell 7+ (`pwsh`), not Windows PowerShell 5.1
- Timezone IDs differ by platform:
  - Windows: "Pacific Standard Time", "Eastern Standard Time"
  - Linux/macOS: "America/Los_Angeles", "America/New_York"
- Use `[Console]::WriteLine()` instead of `Write-Host` for stdout to ensure proper stdio communication
- Path handling in mcp-config.json requires escaped backslashes on Windows: `C:\\Users\\...`
