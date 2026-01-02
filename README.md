# dotbot - AI-Driven Development with Orchestration & Execution

A unified system that transforms AI agents from ad-hoc "vibe coders" into reliable contributors through structured orchestration and battle-tested execution workflows. Pure PowerShell, zero dependencies, cross-platform.

## Vision

**AI agents should work like disciplined team members, not confused interns.**

dotbot provides:
- **Orchestration Layer (MCP)** - Project-native tools that track state, determine intent, and manage feature lifecycles
- **Execution Layer** - Proven workflows, specialized agent personas, and quality standards that guide implementation
- **Profile System** - Technology-specific customization (default, dotnet, python, etc.)
- **File-First Philosophy** - Everything is transparent, git-friendly, human-readable files

The result: AI agents get explicit instructions about what to do next and proven patterns for how to do it.

## What Problem Does This Solve?

Without structure, AI agents:
- 🔴 Get confused about project state ("What was I working on?")
- 🔴 Skip critical steps (no tests, no validation)
- 🔴 Make inconsistent decisions (different approaches each time)
- 🔴 Waste tokens reading entire codebases
- 🔴 Break things when context shifts

With dotbot:
- ✅ Know exactly where they are in the development lifecycle
- ✅ Follow proven workflows (Plan → Shape → Specify → Tasks → Implement → Verify)
- ✅ Apply consistent standards and best practices
- ✅ Get targeted context through MCP tools
- ✅ Track state across sessions

## How It Works

### Two Layers Working Together

**1. Orchestration Layer (MCP Server)**
- Tracks current feature, phase, and task
- Determines "what should happen next" based on project state
- Exposes structured tools: `state.get`, `task.next`, `feature.start`, etc.
- Returns explicit instructions with embedded workflow content
- Eliminates the "read 50 files to understand context" problem

**2. Execution Layer**
- **Workflows** - Step-by-step processes (17 workflows from planning to verification)
- **Agents** - Specialized personas (product-planner, spec-writer, implementer, etc.)
- **Standards** - Quality guardrails organized by domain (backend, frontend, testing)
- **Commands** - Warp command templates for common operations

### Example: Adding a Feature

```bash
# AI agent calls MCP tool
→ intent.next()

# MCP responds with explicit instructions + workflow content
← {
    action: "research-spec",
    reason: "Feature started, ready to shape specification",
    workflow_content: "<full research workflow embedded>",
    phase: "shape",
    current_task: null
  }

# AI agent follows embedded workflow with agent persona
# Workflow guides: research, scope, identify constraints
# Standards enforce: consistent patterns, testing requirements

# When complete, AI updates state
→ state.set({ phase: "specify" })

# Process continues through: specify → tasks → implement → verify
```

## Quick Start

### 1. Install Globally

```powershell
# Clone repository
git clone https://github.com/[user]/dotbot-mcp ~/dotbot-temp
cd ~/dotbot-temp

# Run installation
pwsh init.ps1

# Verify installation
dotbot status
```

This installs dotbot to `~/dotbot` and adds it to your PATH.

### 2. Initialize a Project

```powershell
cd your-project
dotbot init
```

This creates:
- `.bot/` - Agents, workflows, standards, MCP server
- `.warp/workflows/` - Warp workflow integrations
- `.bot/.dotbot-state.json` - Installation tracking

### 3. Connect MCP Server

**For Warp:**
- Settings → Features → MCP Servers
- Add server with command: `pwsh -NoProfile -ExecutionPolicy Bypass -File /path/to/project/.bot/mcp/dotbot-mcp.ps1`

**For Claude Desktop:**
- Edit `claude_desktop_config.json` (see Installation section below)

### 4. Start Developing

Your AI agent can now:
- Query current state: `state.get()`
- Start features: `feature.start({ name: "User Auth" })`
- Get next action: `intent.next()`
- Execute tasks: `task.next()` → follow workflow → `task.complete()`

## Installation

### Global Installation

```powershell
# Clone to temporary location
git clone https://github.com/[user]/dotbot-mcp ~/dotbot-temp
cd ~/dotbot-temp

# Install (cross-platform)
pwsh init.ps1

# Verify
dotbot --version  # Should show: 2.0.0
dotbot help
```

This:
- Copies dotbot to `~/dotbot`
- Adds `~/dotbot/bin` to PATH
- Makes `dotbot` command available globally

### Project Installation

```powershell
cd your-project

# Initialize with default profile
dotbot init

# Or specify profile
dotbot init --profile dotnet
```

### MCP Server Configuration

**Warp:**
```json
// Settings → Features → MCP Servers → Add Server
{
  "command": "pwsh",
  "args": [
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File",
    "/absolute/path/to/project/.bot/mcp/dotbot-mcp.ps1"
  ]
}
```

**Claude Desktop:**
```json
// %APPDATA%\Claude\claude_desktop_config.json (Windows)
// ~/Library/Application Support/Claude/claude_desktop_config.json (macOS)
{
  "mcpServers": {
    "dotbot": {
      "command": "pwsh",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File",
        "/absolute/path/to/project/.bot/mcp/dotbot-mcp.ps1"
      ]
    }
  }
}
```

**Important:** Use absolute paths. On Windows, escape backslashes: `C:\\Users\\...`

## Repository Structure

```
dotbot-mcp/  (repository name)
├── bin/
│   └── dotbot.ps1                    # CLI entry point
├── scripts/                          # Installation system
│   ├── base-install.ps1             # Global installation
│   ├── project-install.ps1          # Project installation
│   ├── Common-Functions.psm1
│   ├── Platform-Functions.psm1
│   └── Template-Processor.psm1
├── profiles/                         # Profile system
│   ├── default/
│   │   ├── agents/                  # 8 specialized personas
│   │   ├── standards/               # 16 coding standards
│   │   ├── workflows/               # 17 development workflows
│   │   ├── commands/                # 7 Warp commands
│   │   └── mcp/                     # MCP orchestration server
│   │       ├── dotbot-mcp.ps1
│   │       ├── dotbot-mcp-helpers.ps1
│   │       ├── metadata.yaml
│   │       └── tools/               # MCP tools (state, intent, task, etc.)
│   └── dotnet/                      # .NET-specific profile
├── config.yml                        # Global configuration
├── init.ps1                          # Smart installer
├── README.md
├── QUICKSTART.md
├── MIGRATION.md                      # For dotbot v1.x users
└── LICENSE
```

## Installed Project Structure

After `dotbot init`, your project has:

```
project/
├── .bot/
│   ├── agents/                       # Execution agents
│   │   ├── implementer.md
│   │   ├── spec-writer.md
│   │   └── ... (8 total)
│   ├── standards/                    # Coding standards
│   │   ├── global/
│   │   ├── backend/
│   │   ├── frontend/
│   │   └── testing/
│   ├── workflows/                    # Execution workflows
│   │   ├── planning/
│   │   ├── specification/
│   │   └── implementation/
│   ├── commands/                     # Warp commands
│   ├── mcp/                          # MCP orchestration server
│   │   ├── dotbot-mcp.ps1           # Server entry point
│   │   ├── dotbot-mcp-helpers.ps1
│   │   ├── metadata.yaml
│   │   └── tools/                    # Orchestration tools
│   │       ├── state.get/           # (Future Phase 3)
│   │       ├── intent.next/
│   │       ├── task.next/
│   │       └── feature.start/
│   ├── .dotbot-state.json           # Installation metadata
│   └── .env                          # API keys (git-ignored)
├── .warp/
│   └── workflows/                    # Warp workflow shims
└── WARP.md                          # Project-specific AI rules (optional)
```

## CLI Commands

### Global Commands
```powershell
dotbot install      # Install dotbot globally
dotbot update       # Update global installation
dotbot uninstall    # Remove global installation
dotbot status       # Show installation status
dotbot help         # Show help
```

### Project Commands
```powershell
dotbot init                    # Initialize current project
dotbot init --profile dotnet   # Initialize with specific profile
dotbot update-project          # Update project to latest
dotbot remove-project          # Remove dotbot from project
```

## MCP Orchestration Tools

### Solution Awareness Tools (Current)

The MCP server provides 7 tools that help AI agents understand your solution structure, tech stack, and coding standards:

**Solution Structure:**
- `solution.info` - High-level solution information (mission, vision, metadata)
- `solution.structure` - Auto-discovered projects with types, aliases, and metadata
- `solution.tech_stack` - Comprehensive tech stack information
- `solution.standards.list` - Available coding standards by domain

**Project Management:**
- `solution.project.register` - Register project with custom metadata (alias, summary, tags)
- `solution.project.update` - Update project metadata

**Health & Validation:**
- `solution.health.check` - Validate dotbot installation, file references, orphan detection

#### Hybrid Discovery Approach

Projects are **always auto-discovered** from the filesystem (`.csproj`, `package.json` files). Optional registry (`.bot/solution/projects.json`) enriches projects with AI-curated metadata.

**Registry precedence:** Custom aliases, summaries, tags, and ownership override auto-discovered values.

**Quick Example:**
```typescript
// Get solution structure - works immediately, no setup required
const structure = await callTool('solution_structure', {});
console.log(`Found ${structure.projects.length} projects`);

// Find backend by alias
const backend = structure.projects.find(p => p.alias === 'be');

// Register project with rich metadata
await callTool('solution_project_register', {
  project_name: backend.name,
  alias: 'api',
  summary: 'Main ASP.NET Core backend API with Bot Framework',
  tags: ['api', 'backend', 'cqrs', 'core'],
  owner: 'platform-team'
});
```

📘 **See [MCP-TOOLS.md](MCP-TOOLS.md) for complete documentation**

### Planned Core Tools (Phase 3)

**State Management:**
- `state.get` - Current feature, phase, task, branch
- `state.set` - Update project state
- `state.history` - Audit trail of state transitions

**Intent & Orchestration:**
- `intent.next` - What should happen next (with embedded workflow content)
- `intent.explain` - Why a particular action is recommended

**Task Management:**
- `task.list` - All tasks with status and dependencies
- `task.next` - Next executable task (with spec excerpts, validation commands)
- `task.start` - Mark task in progress
- `task.complete` - Record completion with evidence

**Feature Lifecycle:**
- `feature.start` - Create feature scaffold, branch, state tracking
- `feature.switch` - Switch between features
- `feature.status` - Current feature progress

**Specification & Context:**
- `spec.section.get` - Extract relevant spec sections
- `project.info` - Project metadata, stack, conventions

## Profiles

dotbot uses profiles to customize content for different technology stacks:

- **default** - General-purpose (8 agents, 16 standards, 17 workflows)
- **dotnet** - .NET-specific standards and workflows
- **python** - (Future) Python ecosystem patterns
- **react** - (Future) React/frontend patterns

Create custom profiles by copying a profile directory and modifying content.

## Development Workflows

dotbot includes battle-tested workflows:

### Planning
- Gather product information
- Determine project strategy
- Produce PRODUCT-MISSION document

### Specification
- Research and scope features
- Write technical specifications
- Review and iterate

### Implementation
- Create task lists from specs
- Implement individual tasks
- Verify implementation
- Handle course corrections

### Standards
- Global patterns (error handling, naming, documentation)
- Backend standards (APIs, databases, security)
- Frontend standards (components, state, accessibility)
- Testing standards (unit, integration, coverage)

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute setup guide
- **[MCP-TOOLS.md](MCP-TOOLS.md)** - Complete MCP tools reference
- **[FRONTMATTER-SPEC.md](FRONTMATTER-SPEC.md)** - YAML frontmatter standard for artifacts
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design
- **[MIGRATION.md](MIGRATION.md)** - Upgrading from dotbot v1.x
- **[profiles/default/mcp/README-NEWTOOL.md](profiles/default/mcp/README-NEWTOOL.md)** - Creating MCP tools
- **[WARP.md](WARP.md)** - Architecture and AI agent guidelines

## Requirements

- **PowerShell 7.0+** (cross-platform)
- **Git** (for version control features)
- No external dependencies or packages

## Platform Support

- ✅ Windows (PowerShell 7+)
- ✅ macOS (via `brew install powershell`)
- ✅ Linux (via package manager)

## Philosophy

### File-First
Everything lives in the repository as plain files. State, specs, workflows, standards - all version-controlled, human-readable, and AI-accessible.

### Convention Over Configuration
Follow directory structures and naming conventions. Tools auto-discover. No manual registration.

### Explicit Over Implicit
MCP tools return resolved instructions with embedded content. No "read these 10 files and figure it out."

### Discipline Over Creativity
AI agents follow proven workflows and standards. Creativity happens within guardrails.

### Project-Native
Each project has its own MCP server and execution framework. No global state, no cross-project confusion.

## License

MIT
