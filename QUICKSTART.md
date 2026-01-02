# Quick Start Guide

## Testing the Server Locally

View example usage patterns:

```powershell
.\examples.ps1
```

Run individual tool tests:

```powershell
# Start the server
$process = Start-Process pwsh -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', '.bot\mcp\dotbot-mcp.ps1'
) -NoNewWindow -PassThru -RedirectStandardInput stdin.txt -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt

# Run a tool test
. .bot\mcp\tools\get-current-datetime\test.ps1 -Process $process

# Clean up
$process | Stop-Process
```

## Setting up with Claude Desktop

### Step 1: Locate Claude Desktop Config

Find your Claude Desktop configuration file:

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

**macOS:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

**Linux:**
```
~/.config/Claude/claude_desktop_config.json
```

### Step 2: Edit Configuration

Open the config file and add the server configuration. If the file doesn't exist, create it with:

```json
{
  "mcpServers": {
    "powershell-date": {
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

**Note:** Replace with your actual installation path. On Windows, use double backslashes: `C:\\Users\\username\\repos\\dotbot-mcp\\.bot\\mcp\\dotbot-mcp.ps1`

### Step 3: Restart Claude Desktop

Close and restart Claude Desktop for the changes to take effect.

### Step 4: Verify Connection

In Claude Desktop, you should now see the MCP server connected. Try asking:

- "What's the current date and time in UTC?"
- "How many days until December 31, 2026?"
- "Convert 2026-01-15 to US date format"
- "What's 45 days from today?"

## Available Tools

1. **get_current_datetime** - Get current date/time with formatting and timezone support
2. **add_to_date** - Add or subtract time from dates
3. **get_date_difference** - Calculate difference between two dates
4. **format_date** - Convert dates between formats
5. **parse_timestamp** - Convert Unix timestamps to readable dates
6. **get_timezones** - List all available system timezones

## Date Format Reference

Common format patterns:

| Pattern | Example | Description |
|---------|---------|-------------|
| `yyyy-MM-dd` | 2026-01-15 | ISO date |
| `MM/dd/yyyy` | 01/15/2026 | US format |
| `dd/MM/yyyy` | 15/01/2026 | UK format |
| `yyyy-MM-dd HH:mm:ss` | 2026-01-15 14:30:00 | ISO datetime |
| `dddd, MMMM dd, yyyy` | Wednesday, January 15, 2026 | Long format |
| `MMM dd, yyyy` | Jan 15, 2026 | Medium format |
| `HH:mm:ss` | 14:30:00 | Time only |
| `o` | 2026-01-15T14:30:00.0000000 | ISO 8601 |

## Troubleshooting

### Server not showing in Claude Desktop

1. Check that PowerShell 7+ is installed: `pwsh --version`
2. Verify the path in `claude_desktop_config.json` is correct and points to `.bot/mcp/dotbot-mcp.ps1`
3. Check Claude Desktop logs for error messages
4. Try running the server manually to see if there are errors:
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1
   ```

### Tool execution errors

1. Check date format strings are valid .NET format strings
2. Ensure dates are in a parseable format (prefer ISO 8601)
3. For timezone issues, use `get_timezones` to list valid IDs

### Interactive Testing

Start the server manually and send JSON-RPC requests:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1
```

Then type JSON-RPC requests (one per line):

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_current_datetime","arguments":{"utc":true}}}
```

Press Ctrl+C to exit.

## Next Steps

- Review `examples.ps1` for usage patterns
- Check `README.md` for detailed documentation
- See `.bot/mcp/README-NEWTOOL.md` for instructions on adding new tools
- Explore the modular tool structure in `.bot/mcp/tools/`

## Support

For issues or questions, check:
- The test script output for diagnostics
- PowerShell error messages in stderr
- Claude Desktop MCP server logs
