# dotbot Architecture

Complete technical overview of the unified orchestration and execution system.

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   AI AGENT (Warp, Claude, Cursor, etc.)               │
│                                                         │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ JSON-RPC over stdio
                 │
┌────────────────▼────────────────────────────────────────┐
│   ORCHESTRATION LAYER (MCP Server)                     │
│   • State tracking (feature, phase, task, branch)      │
│   • Intent determination (what should happen next)     │
│   • Feature lifecycle management                       │
│   • Returns: Explicit instructions + embedded content  │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Embeds workflows, resolves references
                 │
┌────────────────▼────────────────────────────────────────┐
│   EXECUTION LAYER (Workflows + Agents + Standards)     │
│   • Workflows: Step-by-step processes                  │
│   • Agents: Specialized personas                       │
│   • Standards: Quality guardrails                      │
│   • Provides: HOW to execute                           │
└─────────────────────────────────────────────────────────┘
```

## Design Philosophy

### 1. File-First
Everything lives as plain text files in the repository:
- **State**: `.bot/state/*.json` - Project and feature state
- **Specifications**: `specs/*.md` - Technical designs
- **Workflows**: `.bot/workflows/*.md` - Execution processes
- **Standards**: `.bot/standards/**/*.md` - Quality rules
- **Tools**: `.bot/mcp/tools/*/` - Orchestration tools

**Benefits**:
- Version controlled (git history)
- Human readable (markdown, YAML, JSON)
- AI accessible (no database queries needed)
- Transparent (easy to audit and debug)

### 2. Convention Over Configuration
Directory structures and naming determine behavior:
```
.bot/mcp/tools/state.get/
├── script.ps1       # Implementation (Invoke-StateGet function)
├── metadata.yaml    # Tool schema and description
└── test.ps1         # Tool tests
```

No manual registration. No config files. Just follow the pattern.

### 3. Explicit Over Implicit
MCP tools return complete, resolved instructions:

**Bad (implicit)**:
```json
{
  "action": "implement-task",
  "workflow_reference": ".bot/workflows/implementation/implement-tasks.md"
}
```

**Good (explicit)**:
```json
{
  "action": "implement-task",
  "reason": "Task auth-001 ready with all dependencies met",
  "workflow_content": "# Task Implementation\n1. Read spec excerpts...",
  "spec_excerpts": [...],
  "validation_commands": ["npm test", "npm run lint"]
}
```

AI agents get everything they need in one response. No "go read 10 files."

### 4. Discipline Over Creativity
AI agents follow proven patterns:
- **Workflows** define the steps
- **Agents** provide the persona/expertise
- **Standards** enforce quality

Creativity happens **within** these guardrails, not instead of them.

### 5. Project-Native
Each project has its own:
- MCP server (`.bot/mcp/`)
- State tracking (`.bot/state/`)
- Execution framework (`.bot/workflows/`, `.bot/agents/`, `.bot/standards/`)

No global state. No cross-project confusion. Clean isolation.

## Component Architecture

### Orchestration Layer (MCP Server)

**Location**: `.bot/mcp/`

**Purpose**: Project-native intelligence layer

**Components**:
```
.bot/mcp/
├── dotbot-mcp.ps1           # JSON-RPC server
├── dotbot-mcp-helpers.ps1   # Shared functions
├── metadata.yaml            # Server metadata
└── tools/                   # Auto-discovered tools
    ├── state.get/          # Current project state
    ├── state.set/          # Update state
    ├── intent.next/        # What to do next
    ├── task.next/          # Next executable task
    ├── feature.start/      # Begin new feature
    └── [others]/
```

**Tool Structure**:
Each tool is self-contained:
```powershell
# script.ps1
function Invoke-ToolName {
    param([hashtable]$Arguments)
    
    # Load current state
    # Perform logic
    # Return explicit instructions
    
    return @{
        action = "specific-action"
        reason = "why this action now"
        workflow_content = "<full embedded workflow>"
        context = @{ ... }
    }
}
```

**Protocol**: MCP (Model Context Protocol) 2024-11-05
- JSON-RPC 2.0 over stdio
- Tool discovery via `tools/list`
- Tool execution via `tools/call`
- Works with Warp, Claude Desktop, any MCP client

### Execution Layer

**Location**: `.bot/workflows/`, `.bot/agents/`, `.bot/standards/`

**Purpose**: Proven patterns for implementation

#### Workflows (17 total)
Step-by-step processes organized by phase:

**Planning** (`workflows/planning/`):
- `gather-product-info.md` - Establish product vision
- `determine-project-strategy.md` - Technical approach
- `product-mission.md` - Create PRODUCT-MISSION doc

**Specification** (`workflows/specification/`):
- `research-spec.md` - Research and scope feature
- `write-spec.md` - Write technical specification
- `review-spec.md` - Iterate on specification

**Implementation** (`workflows/implementation/`):
- `create-tasks-list.md` - Break spec into tasks
- `implement-tasks.md` - Execute individual task
- `verify-implementation.md` - Validate completion
- `course-correction.md` - Handle issues

**Format**:
```markdown
# Workflow Name

## Goal
What this workflow achieves

## Context
When to use this

## Steps
1. Step one with clear action
2. Step two with validation
3. Step three with output

## Output
What gets created

## Next Workflow
What comes after
```

#### Agents (8 total)
Specialized personas that guide AI behavior:

**Location**: `.bot/agents/`

**Types**:
- `product-planner.md` - Vision and strategy
- `spec-writer.md` - Technical specifications
- `researcher.md` - Investigation and analysis
- `implementer.md` - Code execution
- `reviewer.md` - Code review
- `debugger.md` - Problem solving
- `tester.md` - Testing and validation
- `documenter.md` - Documentation

**Format**:
```markdown
# Agent Name

## Role
Your specific responsibility

## Expertise
What you're good at

## Approach
How you work

## Standards
Quality expectations
```

#### Standards (16 total)
Quality guardrails organized by domain:

**Location**: `.bot/standards/`

**Global** (`global/`):
- Naming conventions
- Error handling patterns
- Documentation requirements
- Git workflow

**Backend** (`backend/`):
- API design
- Database patterns
- Security practices
- Performance

**Frontend** (`frontend/`):
- Component structure
- State management
- Accessibility
- Responsive design

**Testing** (`testing/`):
- Unit tests
- Integration tests
- Test coverage
- Test organization

**Format**:
```markdown
# Standard Name

## Principle
Core rule

## Pattern
How to apply

## Example
Code demonstration

## Anti-pattern
What NOT to do
```

### Installation System

**Global Installation** (`~/dotbot`):
```
~/dotbot/
├── bin/
│   └── dotbot.ps1          # CLI entry point
├── scripts/                # Installation system
├── profiles/               # Profile templates
│   ├── default/
│   └── dotnet/
└── config.yml              # Global configuration
```

**Project Installation** (`.bot/`):
```
.bot/
├── agents/                 # Copied from profile
├── workflows/              # Copied from profile
├── standards/              # Copied from profile
├── commands/               # Copied from profile
├── mcp/                    # Copied from profile
└── .dotbot-state.json      # Installation metadata
```

**Profile System**:
Profiles customize content for technology stacks:
- `default`: General-purpose patterns
- `dotnet`: .NET-specific standards
- `python`: Python ecosystem (planned)
- `react`: React/frontend (planned)

Each profile contains:
```
profiles/[name]/
├── agents/
├── standards/
├── workflows/
├── commands/
└── mcp/                    # Optional: profile-specific tools
```

### State Management (Phase 3)

**Location**: `.bot/state/`

**Structure**:
```
.bot/state/
├── current.json            # Current project state
├── history/                # State transitions
│   └── 2026-01-02-*.json
└── features/               # Feature-specific state
    └── feature-001/
        ├── state.json      # Feature metadata
        ├── tasks.json      # Task list with dependencies
        └── audit.json      # Event log
```

**State Schema**:
```json
{
  "version": "1.0",
  "project": {
    "name": "project-name",
    "platform": "windows|macos|linux",
    "stack": ["language", "framework"]
  },
  "current": {
    "feature_id": "feature-001",
    "phase": "implement",
    "task_id": "task-003",
    "branch": "feature/user-auth",
    "last_commit": "abc123"
  },
  "timestamp": "2026-01-02T08:00:00Z"
}
```

## Data Flow

### Complete Feature Implementation Flow

1. **Start Feature**:
   ```
   AI Agent → MCP: feature.start({ name: "User Auth" })
   MCP → State: Create feature-001/, update current.json
   MCP → Git: Create branch feature/user-auth
   MCP → AI: { feature_id, branch, next_action: "research-spec" }
   ```

2. **Get Next Intent**:
   ```
   AI Agent → MCP: intent.next()
   MCP → State: Read current phase ("shape")
   MCP → Workflows: Load research-spec.md
   MCP → AI: {
     action: "research-spec",
     workflow_content: "<full embedded workflow>",
     phase: "shape",
     rules: ["<course-correction rules>"]
   }
   ```

3. **Execute Workflow**:
   ```
   AI Agent: Read embedded workflow content
   AI Agent: Follow steps (research, scope, constraints)
   AI Agent: Apply agent persona (spec-writer)
   AI Agent: Enforce standards (global, backend)
   AI Agent: Create specification document
   ```

4. **Update State**:
   ```
   AI Agent → MCP: state.set({ phase: "specify" })
   MCP → State: Update current.json, save to history/
   MCP → AI: { success: true, next_phase: "specify" }
   ```

5. **Write Specification**:
   ```
   AI Agent → MCP: intent.next()
   MCP → AI: {
     action: "write-spec",
     workflow_content: "<write-spec workflow>",
     research_notes: "<from previous phase>"
   }
   AI Agent: Execute workflow
   AI Agent: Create specs/user-authentication.md
   ```

6. **Create Tasks**:
   ```
   AI Agent → MCP: state.set({ phase: "tasks" })
   AI Agent → MCP: intent.next()
   MCP → AI: { action: "create-tasks-list", workflow_content: "..." }
   AI Agent: Execute workflow
   AI Agent: Create task list in .bot/state/features/feature-001/tasks.json
   ```

7. **Implement Tasks**:
   ```
   AI Agent → MCP: task.next()
   MCP → Tasks: Find next task with satisfied dependencies
   MCP → Specs: Extract relevant sections
   MCP → AI: {
     task: {
       id: "auth-001",
       description: "Implement login endpoint",
       spec_excerpts: ["<relevant spec sections>"],
       validation: ["npm test auth.test.js"],
       depends_on: []
     }
   }
   AI Agent: Execute with implementer agent + standards
   AI Agent → MCP: task.complete({ commit: "abc123" })
   ```

8. **Repeat** until all tasks complete

9. **Verify**:
   ```
   AI Agent → MCP: state.set({ phase: "verify" })
   AI Agent → MCP: intent.next()
   MCP → AI: { action: "verify-implementation", workflow_content: "..." }
   AI Agent: Run all tests, linting, validation
   AI Agent: Mark feature complete
   ```

## Extension Points

### Creating Custom MCP Tools

**Location**: `profiles/default/mcp/tools/your-tool/`

**1. Create directory**:
```powershell
mkdir profiles/default/mcp/tools/your-tool
```

**2. Create metadata.yaml**:
```yaml
name: your_tool
description: What this tool does
inputSchema:
  type: object
  properties:
    param_name:
      type: string
      description: Parameter purpose
```

**3. Create script.ps1**:
```powershell
function Invoke-YourTool {
    param([hashtable]$Arguments)
    
    # Get parameter
    $paramValue = $Arguments['param_name']
    
    # Perform logic
    $result = Do-Something -Value $paramValue
    
    # Return structured data
    return @{
        success = $true
        data = $result
    }
}
```

**4. Create test.ps1**:
```powershell
function Test-YourTool {
    Write-Host "Testing your-tool..."
    
    # Test logic
    $result = Invoke-YourTool -Arguments @{ param_name = "test" }
    
    if ($result.success) {
        Write-Host "✓ Test passed" -ForegroundColor Green
    } else {
        Write-Host "✗ Test failed" -ForegroundColor Red
    }
}
Test-YourTool
```

**5. Reinstall**: `dotbot update-project` picks up new tool automatically

### Creating Custom Profiles

**1. Copy existing profile**:
```powershell
cp -r ~/dotbot/profiles/default ~/dotbot/profiles/myprofile
```

**2. Customize content**:
- Modify agents for your domain
- Update standards for your stack
- Adjust workflows for your process
- Add profile-specific MCP tools

**3. Use profile**:
```powershell
dotbot init --profile myprofile
```

### Extending Workflows

**1. Create new workflow**:
```powershell
# In your project
cp .bot/workflows/implementation/implement-tasks.md .bot/workflows/custom/my-workflow.md
```

**2. Reference from other workflows**:
```markdown
## Next Steps
See {{workflows/custom/my-workflow}} for details.
```

**3. Or call from MCP tools**:
```powershell
# In intent.next tool
$workflowPath = ".bot/workflows/custom/my-workflow.md"
$content = Get-Content $workflowPath -Raw
return @{ workflow_content = $content }
```

## Security Considerations

### API Keys
- Never commit `.env` files (in `.gitignore`)
- Use environment variables for secrets
- MCP tools can access `$env:` variables
- Document required keys in README

### MCP Server
- Runs in project directory (no system access)
- Sandboxed to `.bot/` and project files
- No network access by default
- Tools explicitly define capabilities

### State Files
- `.bot/state/` contains no secrets
- Safe to commit to version control
- Contains only project metadata
- History useful for debugging

## Performance

### MCP Tool Response Time
- Target: <100ms for state queries
- Target: <500ms for intent determination
- Optimization: Cache workflow content
- Optimization: Pre-load common data

### Workflow Content Size
- Keep workflows <5KB each
- Use references for shared content
- Embed only relevant sections
- Inline critical instructions

### Installation
- Global install: ~10 seconds
- Project install: ~5 seconds
- 84 files copied per project
- Template processing: <1 second

## Troubleshooting

### MCP Server Not Responding
1. Check server process: `Get-Process | Where Name -like "*pwsh*"`
2. Test manually: `pwsh .bot/mcp/dotbot-mcp.ps1`
3. Verify JSON-RPC: Send `initialize` request
4. Check PowerShell version: `pwsh --version` (need 7.0+)

### Tools Not Discovered
1. Check directory structure: `ls .bot/mcp/tools/*/`
2. Verify metadata.yaml exists in each tool
3. Ensure script.ps1 has `Invoke-{ToolName}` function
4. Restart MCP server after changes

### State Not Updating
1. Verify state files exist: `ls .bot/state/`
2. Check file permissions
3. Verify JSON is valid: `cat .bot/state/current.json | ConvertFrom-Json`
4. Check history: `ls .bot/state/history/`

### Template Variables Not Expanding
1. Verify `{{variable}}` syntax
2. Check Template-Processor.psm1 loaded
3. Ensure variables defined in project-install.ps1
4. Test: `dotbot init --dry-run --verbose`

## Future Enhancements

### Phase 3 (In Progress)
- Complete orchestration tools (state, task, feature, intent)
- State management system
- Task dependency resolution
- Feature lifecycle tracking

### Phase 4 (Planned)
- Multi-agent collaboration
- Automated testing orchestration
- Deployment workflows
- Monitoring and observability

### Phase 5 (Ideas)
- Team coordination
- Cross-project insights
- Pattern library
- Community profiles

## References

- [README.md](README.md) - Overview and quick start
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup guide
- [MIGRATION.md](MIGRATION.md) - Upgrading from v1.x
- [WARP.md](WARP.md) - AI agent guidelines
- [MCP Protocol](https://modelcontextprotocol.io/) - Official spec
