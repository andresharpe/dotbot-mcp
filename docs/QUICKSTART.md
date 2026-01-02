# Quick Start Guide - dotbot v2.0

Get up and running with dotbot in 5 minutes. This guide covers global installation, project setup, MCP server connection, and your first workflow execution.

## What You'll Get

After following this guide:
- ✅ **Global CLI** - `dotbot` command available everywhere
- ✅ **Project Setup** - `.bot/` with agents, workflows, standards, MCP server
- ✅ **MCP Integration** - AI agent connected to orchestration tools
- ✅ **Ready to Code** - Structured development workflows at your fingertips

## Prerequisites

- PowerShell 7.0+ (check: `pwsh --version`)
- Git (for version control features)
- A project directory (or create one)

## Step 1: Global Installation

```powershell
# Clone dotbot to temporary location
git clone https://github.com/[user]/dotbot-mcp ~/dotbot-temp
cd ~/dotbot-temp

# Run installer (cross-platform)
pwsh init.ps1
```

The installer will:
- Copy dotbot to `~/dotbot`
- Add `~/dotbot/bin` to your PATH
- Make `dotbot` command globally available

**Verify installation:**
```powershell
dotbot status
# Should show: dotbot v2.0.0 installed

dotbot help
# Shows available commands
```

## Step 2: Initialize a Project

Navigate to your project and initialize dotbot:

```powershell
cd ~/my-project

# Initialize with default profile
dotbot init

# Or use a specific profile (e.g., dotnet, python)
dotbot init --profile dotnet
```

This creates:
```
.bot/
├── agents/           # 8 specialized AI personas
├── standards/        # Coding standards and best practices
├── workflows/        # 17 development workflows
├── commands/         # Warp command templates
├── mcp/              # MCP orchestration server
└── .dotbot-state.json

.warp/
└── workflows/        # Warp workflow integrations
```

## Step 3: Connect MCP Server

### Option A: Warp (Recommended)

1. Open Warp Settings → Features → MCP Servers
2. Click "Add Server"
3. Configure:
   - **Name:** `dotbot`
   - **Command:** `pwsh`
   - **Args:**
     ```json
     [
       "-NoProfile",
       "-ExecutionPolicy", "Bypass",
       "-File",
       "/absolute/path/to/your-project/.bot/mcp/dotbot-mcp.ps1"
     ]
     ```

**Windows path example:** `C:\\Users\\andre\\projects\\my-app\\.bot\\mcp\\dotbot-mcp.ps1`

**macOS/Linux path example:** `/Users/andre/projects/my-app/.bot/mcp/dotbot-mcp.ps1`

4. Save and verify connection

### Option B: Claude Desktop

1. Locate config file:
   - **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
   - **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Linux:** `~/.config/Claude/claude_desktop_config.json`

2. Add server configuration:
   ```json
   {
     "mcpServers": {
       "dotbot": {
         "command": "pwsh",
         "args": [
           "-NoProfile",
           "-ExecutionPolicy", "Bypass",
           "-File",
           "/absolute/path/to/your-project/.bot/mcp/dotbot-mcp.ps1"
         ]
       }
     }
   }
   ```

3. Restart Claude Desktop

## Step 4: Verify MCP Connection

Test the MCP server is working:

**In Warp or Claude, try:**
- "What MCP tools are available?"
- "What's the current date and time?" (uses example date/time tools)

**Manual test (optional):**
```powershell
# Start server
cd ~/my-project
pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1

# In another terminal, send JSON-RPC request
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | pwsh -Command "$input | pwsh -NoProfile -File .bot/mcp/dotbot-mcp.ps1"
```

Press Ctrl+C to stop the server.

## Step 5: Understanding the System

### Orchestration vs Execution

**Orchestration Layer (MCP Server):**
- Tracks project state (feature, phase, task)
- Determines "what to do next"
- Provides structured tools: `state.get`, `task.next`, `feature.start`
- Eliminates context confusion

**Execution Layer (Workflows + Agents + Standards):**
- **Workflows** - Step-by-step guides (`.bot/workflows/`)
- **Agents** - Specialized personas (`.bot/agents/`)
- **Standards** - Quality guardrails (`.bot/standards/`)
- Provides "how to do it"

### Your First Workflow

Let's walk through adding a feature:

1. **Plan the product** (if first time):
   ```markdown
   # AI agent reads workflow
   .bot/workflows/planning/gather-product-info.md
   
   # Follows steps:
   - Research product context
   - Define user problems
   - Create PRODUCT-MISSION.md
   ```

2. **Start a feature:**
   ```markdown
   # Future: AI agent calls MCP tool
   feature.start({ name: "User Authentication" })
   
   # Creates:
   - Feature tracking state
   - Git branch
   - Feature directory
   ```

3. **Research specification:**
   ```markdown
   # AI agent gets next intent
   intent.next() → "research-spec"
   
   # Follows workflow (embedded in response)
   - Research requirements
   - Identify constraints
   - Scope boundaries
   ```

4. **Write specification:**
   ```markdown
   # AI agent moves to specify phase
   state.set({ phase: "specify" })
   
   # Follows workflow
   .bot/workflows/specification/write-spec.md
   ```

5. **Implement tasks:**
   ```markdown
   # AI agent gets next task
   task.next() → { id: "auth-001", description: "...", spec_excerpts: [...] }
   
   # Implements following standards
   .bot/standards/backend/
   .bot/standards/testing/
   
   # Marks complete
   task.complete({ commit: "abc123" })
   ```

**Note:** Phase 3 MCP tools (state, task, feature management) are planned. Currently includes example date/time tools to demonstrate architecture.

## Available MCP Tools (Current)

Example tools included to demonstrate MCP architecture:

1. **get_current_datetime** - Current date/time with timezone support
2. **add_to_date** - Date arithmetic
3. **get_date_difference** - Time spans between dates
4. **format_date** - Convert date formats
5. **parse_timestamp** - Unix timestamp conversion
6. **get_timezones** - List system timezones
7. **get_public_holidays** - Holiday checking (requires API key)
8. **get_current_time_at** - Time at location (requires API key)

## Troubleshooting

### dotbot command not found

```powershell
# Verify installation
ls ~/dotbot

# Re-run installer
cd ~/dotbot-temp
pwsh init.ps1

# Check PATH (should include ~/dotbot/bin)
$env:PATH -split (';')
```

### MCP Server Not Connecting

1. **Check PowerShell version:** `pwsh --version` (need 7.0+)
2. **Verify path is absolute** and points to `.bot/mcp/dotbot-mcp.ps1`
3. **Test server manually:**
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File .bot/mcp/dotbot-mcp.ps1
   # Should start without errors
   ```
4. **Check client logs:**
   - Warp: Settings → Developer → Logs
   - Claude: Help → View Logs

### Project Installation Issues

```powershell
# Check if git repo
git status

# Re-initialize
dotbot remove-project
dotbot init

# Check state file
cat .bot/.dotbot-state.json
```

## Next Steps

### Explore the System
```powershell
# View workflows
ls .bot/workflows/

# Read an agent persona
cat .bot/agents/implementer.md

# Check standards
ls .bot/standards/
```

### Customize Your Installation
```powershell
# Update to latest
dotbot update

# Use different profile
dotbot init --profile dotnet

# Check current status
dotbot status
```

### Learn More
- **[README.md](README.md)** - Complete documentation
- **[MIGRATION.md](MIGRATION.md)** - Upgrading from dotbot v1.x
- **[WARP.md](WARP.md)** - Architecture and AI guidelines
- **[profiles/default/mcp/README-NEWTOOL.md](profiles/default/mcp/README-NEWTOOL.md)** - Creating MCP tools

## What's Next?

You're ready to start structured AI-driven development:

1. **Start with planning** - Let AI agent gather product info
2. **Define features** - Use specification workflows
3. **Implement systematically** - Follow task workflows with standards
4. **Track everything** - MCP tools maintain state (Phase 3)

**Welcome to disciplined AI development!** 🎉
