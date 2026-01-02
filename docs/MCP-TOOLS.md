# MCP Tools Reference

This document provides comprehensive documentation for all MCP tools provided by dotbot-mcp.

## Table of Contents
- [Solution Awareness Tools](#solution-awareness-tools)
  - [solution.info](#solutioninfo)
  - [solution.structure](#solutionstructure)
  - [solution.tech_stack](#solutiontech_stack)
  - [solution.standards.list](#solutionstandardslist)
  - [solution.project.register](#solutionprojectregister)
  - [solution.project.update](#solutionprojectupdate)
  - [solution.health.check](#solutionhealthcheck)
- [State Management Tools](#state-management-tools)
  - [state.set](#stateset)
  - [state.get](#stateget)
  - [state.advance](#stateadvance)
  - [state.reset](#statereset)
  - [state.history](#statehistory)
- [Date & Time Tools](#date--time-tools)

---

## Envelope Response Format

All `solution.*` tools return responses in a standardized **envelope format** that wraps the actual data with metadata, error handling, and audit information.

### Response Structure

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution-info",
  "version": "1.0.0",
  "status": "ok|warning|error",
  "summary": "One-sentence summary",
  "data": { /* tool-specific output */ },
  "warnings": [],
  "errors": [],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 123,
    "source": ".bot/mcp/tools/solution-info/script.ps1",
    "host": "warp"
  }
}
```

### Key Benefits

- **Consistency**: Same structure across all tools
- **Error Handling**: Structured errors with error codes
- **Observability**: Timing, source tracking, audit trails
- **Status Auto-Computation**: `status` field computed from errors/warnings
- **Kebab-Case Naming**: Tool names use kebab-case (e.g., `solution-info`, `solution-tech-stack`)

### Status Field

The `status` field is automatically computed:
- `"error"`: If `errors.length > 0`
- `"warning"`: If `warnings.length > 0` AND `errors.length == 0`
- `"ok"`: If both `errors.length == 0` AND `warnings.length == 0`

### Output Examples

Throughout this document, output examples show the `data` field content for brevity. In practice, all responses are wrapped in the envelope format shown above.

📘 **For complete envelope specification, see [ENVELOPE-RESPONSE-STANDARD.md](./ENVELOPE-RESPONSE-STANDARD.md)**

---

## Solution Awareness Tools

Solution Awareness Tools help AI agents understand the structure, tech stack, and organization of dotbot-managed repositories. They use a **hybrid discovery approach**: auto-discovering projects from the filesystem while allowing optional metadata enrichment through a registry.

### Key Concepts

**Solution**: The entire dotbot-managed repository containing a `.bot/` directory (e.g., "Axiome")

**Projects**: Individual buildable components within the solution (e.g., `Axiome.Bot.Core`, `axiome-frontend`)

**Aliases**: Short identifiers for projects (e.g., `be`, `fe`, `psx`) used throughout tooling

**Registry**: Optional metadata file (`.bot/solution/projects.json`) that enriches auto-discovered projects with AI-curated information

**Hybrid Discovery**: Projects are always auto-discovered from filesystem, with registry data taking precedence for metadata fields (alias, summary, tags, owner)

---

### solution.info

Returns high-level solution/product information including mission, vision, and metadata.

#### Input Schema
```json
{
  "include_mission": true,     // Include product mission and vision
  "include_roadmap": false     // Include product roadmap summary
}
```

#### Output Example
```json
{
  "solution": {
    "name": "Axiome",
    "dotbot_version": "1.3.25",
    "profile": "dotnet",
    "installed_at": "2025-11-20T14:58:15Z"
  },
  "mission": {
    "vision": "AI-powered compliance automation platform...",
    "problem_statement": "Manual compliance processes are time-consuming...",
    "target_users": ["Compliance Officers", "Risk Managers"],
    "value_proposition": "Reduce compliance overhead by 80%..."
  },
  "file_references": {
    "primary_files": [
      ".bot/.dotbot-state.json",
      ".bot/product/mission.md"
    ]
  }
}
```

#### Usage Examples
```typescript
// Get basic solution info
const info = await callTool('solution_info', {
  include_mission: true,
  include_roadmap: false
});

console.log(`Working in ${info.solution.name} (dotbot v${info.solution.dotbot_version})`);
```

---

### solution.structure

Returns solution structure with all detected projects, their types, aliases, and metadata.

#### Input Schema
```json
{
  "include_dependencies": false,  // Include dependency counts
  "include_file_counts": false    // Include file counts by type
}
```

#### Output Example
```json
{
  "solution_root": "C:\\repos\\Axiome",
  "solution_name": "Axiome",
  "projects": [
    {
      "alias": "be",
      "name": "Axiome.Bot",
      "type": "dotnet-web",
      "path": "Axiome.Bot",
      "target_framework": "net10.0",
      "dependency_count": 18,
      "summary": "ASP.NET Core backend API"
    },
    {
      "alias": "fe",
      "name": "axiome-frontend",
      "type": "nextjs-app",
      "path": "axiome-frontend",
      "version": "0.1.0",
      "framework": "Next.js 16.0.3",
      "dependency_count": 35,
      "summary": "Next.js frontend with React 19"
    }
  ],
  "key_directories": [
    { "name": "docs", "purpose": "Documentation" },
    { "name": "scripts", "purpose": "Automation scripts" }
  ],
  "solution_files": ["Axiome.sln"]
}
```

#### Project Types
- `dotnet-web` - ASP.NET Core web applications
- `dotnet-console` - Console applications
- `dotnet-library` - Class libraries
- `dotnet-test` - Test projects (xUnit, NUnit, MSTest)
- `nextjs-app` - Next.js applications
- `react-app` - React applications
- `test-project` - Frontend test projects

#### Alias Generation Rules
- Frontend projects → `fe` (or `fe-{suffix}` if multiple)
- Backend/API projects → `be` (or `be-{suffix}` if multiple)
- Test projects → `{target}-test` (e.g., `be-test`, `fe-test`)
- Special projects → abbreviated name (e.g., `psx`, `mcp-ps`)

**Registry Override**: If a project is registered with a custom alias, the registry value always wins.

#### Usage Examples
```typescript
// Get all projects
const structure = await callTool('solution_structure', {});
console.log(`Found ${structure.projects.length} projects`);

// Find backend project
const backend = structure.projects.find(p => p.alias === 'be');
console.log(`Backend: ${backend.name} (${backend.type})`);

// Get projects with dependencies
const withDeps = await callTool('solution_structure', {
  include_dependencies: true
});
```

---

### solution.tech_stack

Returns comprehensive tech stack information from `.bot/product/tech-stack.md`.

#### Input Schema
```json
{
  "category": "all",              // Filter: all, backend, frontend, database, testing, deployment, ai, security
  "include_versions": true,       // Include specific version numbers
  "include_rationale": false      // Include rationale for technology choices
}
```

#### Output Example
```json
{
  "backend": {
    "framework": "ASP.NET Core 10.0",
    "language": "C# 13 / .NET 10.0",
    "key_libraries": [
      { "name": "MediatR", "version": "13.1.0", "purpose": "CQRS pattern" },
      { "name": "FluentValidation", "version": "11.3.1", "purpose": "Request validation" }
    ]
  },
  "frontend": {
    "framework": "Next.js 16.0.3",
    "language": "TypeScript 5+",
    "ui_library": "shadcn/ui with Radix UI primitives"
  },
  "database": {
    "primary": "PostgreSQL 16",
    "orm": "Entity Framework Core 10.0"
  }
}
```

#### Usage Examples
```typescript
// Get all tech stack info
const stack = await callTool('solution_tech_stack', {
  category: 'all',
  include_versions: true
});

// Get only backend stack with rationale
const backend = await callTool('solution_tech_stack', {
  category: 'backend',
  include_rationale: true
});
```

---

### solution.standards.list

Lists available coding standards with optional filtering by domain.

#### Input Schema
```json
{
  "domain": "all",                // Filter: all, global, backend, frontend, testing, security, deployment
  "include_summaries": true,      // Include brief summary of each standard
  "applicable_to": null           // Filter to project alias (e.g., "fe", "be")
}
```

#### Output Example
```json
{
  "standards": [
    {
      "file": ".bot/standards/global/naming-conventions.md",
      "domain": "global",
      "title": "Naming Conventions",
      "summary": "Consistent naming for files, classes, methods, variables",
      "applies_to": ["all-projects"]
    },
    {
      "file": ".bot/standards/backend/dotnet-api-design.md",
      "domain": "backend",
      "title": ".NET API Design",
      "summary": "RESTful API conventions, MediatR patterns, validation",
      "applies_to": ["dotnet-web", "dotnet-library"]
    }
  ],
  "summary": {
    "total": 16,
    "by_domain": {
      "global": 3,
      "backend": 5,
      "frontend": 4,
      "testing": 2,
      "security": 2
    }
  }
}
```

#### Usage Examples
```typescript
// List all standards
const allStandards = await callTool('solution_standards_list', {
  domain: 'all',
  include_summaries: true
});

// Get standards for frontend project
const feStandards = await callTool('solution_standards_list', {
  applicable_to: 'fe'
});

// Get only backend standards
const backendStandards = await callTool('solution_standards_list', {
  domain: 'backend'
});
```

---

### solution.project.register

Registers or updates project metadata in the registry (`.bot/solution/projects.json`).

#### Input Schema
```json
{
  "project_name": "Axiome.Bot",     // Required: Full project name
  "alias": "be",                     // Optional: Short alias
  "summary": "Main backend API",     // Optional: Description
  "tags": ["api", "core"],           // Optional: Categorization tags
  "owner": "backend-team"            // Optional: Responsible team/person
}
```

#### Output Example
```json
{
  "success": true,
  "project_name": "Axiome.Bot",
  "registered_metadata": {
    "alias": "be",
    "summary": "Main ASP.NET Core backend API",
    "tags": ["api", "backend", "core"],
    "owner": "backend-team"
  },
  "message": "Project registered successfully"
}
```

#### Usage Examples
```typescript
// Register a new project with full metadata
await callTool('solution_project_register', {
  project_name: 'Axiome.PeopleSoftExtractor',
  alias: 'psx',
  summary: 'PeopleSoft data extraction library',
  tags: ['integration', 'peoplesoft', 'etl'],
  owner: 'integration-team'
});

// Register with minimal metadata (alias only)
await callTool('solution_project_register', {
  project_name: 'axiome-frontend',
  alias: 'fe'
});
```

---

### solution.project.update

Updates specific metadata fields for an already-registered project.

#### Input Schema
```json
{
  "project_name": "Axiome.Bot",     // Required: Project name or alias
  "alias": "be",                     // Optional: New alias
  "summary": "Updated summary",      // Optional: New summary
  "tags": ["api", "core"],           // Optional: New tags (replaces existing)
  "owner": "new-team"                // Optional: New owner
}
```

#### Output Example
```json
{
  "success": true,
  "project_name": "Axiome.Bot",
  "updated_fields": ["summary", "tags"],
  "current_metadata": {
    "alias": "be",
    "summary": "Updated summary",
    "tags": ["api", "core"],
    "owner": "backend-team"
  }
}
```

#### Usage Examples
```typescript
// Update just the summary
await callTool('solution_project_update', {
  project_name: 'be',  // Can use alias
  summary: 'Main ASP.NET Core API with Bot Framework integration'
});

// Update multiple fields
await callTool('solution_project_update', {
  project_name: 'Axiome.Bot',
  summary: 'Updated description',
  tags: ['api', 'backend', 'bot-framework', 'core'],
  owner: 'platform-team'
});
```

---

### solution.health.check

Validates dotbot installation, solution structure, and file integrity.

#### Input Schema
```json
{
  "check_level": "standard",          // Level: basic, standard, comprehensive
  "include_recommendations": true     // Include improvement suggestions
}
```

#### Check Levels

**Basic**: Core installation validation
- `.bot/` directory exists
- `.dotbot-state.json` is valid
- Required subdirectories present

**Standard** (includes Basic):
- Agent/workflow/standard counts match expected
- Product artifacts exist
- Projects detected successfully

**Comprehensive** (includes Standard):
- YAML frontmatter validation on all artifacts
- File reference integrity (broken links detection)
- Orphan file detection (unused files)
- Circular reference detection
- Git repository initialization
- Test project coverage ratio

#### Output Example
```json
{
  "status": "warning",
  "checks": [
    {
      "category": "dotbot-installation",
      "status": "pass",
      "checks": [
        { "name": ".bot directory exists", "status": "pass" },
        { "name": "agents installed", "status": "pass", "count": 8 }
      ]
    },
    {
      "category": "frontmatter-validation",
      "status": "warning",
      "checks": [
        { "name": "workflows have frontmatter", "status": "warning", "missing_count": 2 }
      ]
    },
    {
      "category": "file-reference-integrity",
      "status": "error",
      "checks": [
        { "name": "workflow references valid", "status": "error", "broken_count": 3 }
      ]
    },
    {
      "category": "orphan-files",
      "status": "warning",
      "checks": [
        { "name": "orphan workflows", "status": "warning", "count": 5 }
      ]
    }
  ],
  "issues": [
    {
      "severity": "error",
      "category": "file-references",
      "message": "3 broken file references detected",
      "details": [
        {
          "source": ".bot/workflows/planning/old-workflow.md",
          "reference": "@.bot/agents/deprecated-agent.md",
          "issue": "Referenced file does not exist"
        }
      ],
      "recommendation": "Fix or remove broken references"
    }
  ],
  "recommendations": [
    {
      "category": "documentation",
      "message": "Consider adding README.md files to individual project directories"
    }
  ]
}
```

#### Usage Examples
```typescript
// Quick basic check
const basic = await callTool('solution_health_check', {
  check_level: 'basic'
});
console.log(`Status: ${basic.status}`);

// Comprehensive check for CI/CD
const comprehensive = await callTool('solution_health_check', {
  check_level: 'comprehensive',
  include_recommendations: true
});

if (comprehensive.status === 'error') {
  console.error('Critical issues found:');
  comprehensive.issues
    .filter(i => i.severity === 'error')
    .forEach(i => console.error(`  - ${i.message}`));
}
```

---

## Registry Precedence Rules

The hybrid discovery system ensures projects work **without registration** while allowing **metadata enrichment**.

### Precedence Order
1. **Registry metadata** (if project is registered) - ALWAYS WINS
2. **Auto-discovered metadata** (fallback if not registered)
3. **Inferred defaults** (if no discovery data available)

### Fields with Registry Precedence
- `alias` - Registry alias overrides auto-generated alias
- `summary` - Registry summary overrides inferred summary
- `tags` - Registry tags override inferred tags
- `owner` - Registry owner overrides nothing (only source)

### Fields Always from Discovery
- `name` - Project name from filesystem
- `type` - Project type from file analysis
- `path` - Physical path from filesystem
- `target_framework` - From .csproj or package.json
- `dependency_count` - From package references
- `version` - From package.json

### Workflow Example
```typescript
// Step 1: Get initial structure (no registration)
const structure = await callTool('solution_structure', {});
// All projects have auto-generated aliases and inferred metadata

// Step 2: Register project with rich metadata
await callTool('solution_project_register', {
  project_name: 'Axiome.Bot',
  alias: 'api',  // Override auto-generated 'be'
  summary: 'Main ASP.NET Core backend API with Bot Framework integration',
  tags: ['api', 'backend', 'bot-framework', 'cqrs', 'core'],
  owner: 'platform-team'
});

// Step 3: Get structure again - registry data takes precedence
const updated = await callTool('solution_structure', {});
const backend = updated.projects.find(p => p.name === 'Axiome.Bot');
// backend.alias === 'api' (from registry, not auto-generated 'be')
// backend.summary === 'Main ASP.NET Core...' (from registry, not inferred)
// backend.type === 'dotnet-web' (still from discovery)
```

---

## Common Scenarios

### Onboarding New Developer
```typescript
// Get high-level overview
const info = await callTool('solution_info', {
  include_mission: true,
  include_roadmap: true
});
console.log(info.mission.vision);

// Understand structure
const structure = await callTool('solution_structure', {
  include_dependencies: true
});
console.log(`${structure.projects.length} projects in solution`);

// Learn tech stack
const stack = await callTool('solution_tech_stack', {
  category: 'all',
  include_versions: true
});
console.log(`Backend: ${stack.backend.framework}`);
console.log(`Frontend: ${stack.frontend.framework}`);
```

### Project Registration Workflow
```typescript
// Discover projects
const structure = await callTool('solution_structure', {});

// Register each with rich metadata
for (const project of structure.projects) {
  await callTool('solution_project_register', {
    project_name: project.name,
    alias: inferAlias(project),
    summary: generateSummary(project),
    tags: inferTags(project),
    owner: determineOwner(project)
  });
}
```

### Health Check in CI/CD
```typescript
// Run comprehensive health check
const health = await callTool('solution_health_check', {
  check_level: 'comprehensive',
  include_recommendations: true
});

// Fail build on errors
if (health.status === 'error') {
  const errors = health.issues.filter(i => i.severity === 'error');
  console.error(`${errors.length} critical issues found`);
  process.exit(1);
}

// Warn on issues
if (health.status === 'warning') {
  const warnings = health.issues.filter(i => i.severity === 'warning');
  console.warn(`${warnings.length} warnings found`);
}
```

---

## State Management Tools

State Management Tools provide deterministic, repo-native tracking of feature development progression. These tools coordinate **intent, scope, and progression** while remaining separate from workflows, agents, and standards.

### Key Concepts

**State**: Current development context tracked in `.bot/state/state.json`

**History**: Append-only audit trail in `.bot/state/history.ndjson`

**Deterministic**: State is ONLY changed by explicit tool calls, never inferred from git/filesystem

**Integration Layer**: State tools track *what* and *where* you are, not *how* to do the work

📘 **For complete state management guide, see [STATE-MANAGEMENT.md](./STATE-MANAGEMENT.md)**

---

### state.set

Initialize or update state fields with validation and history tracking.

#### Input Schema
```json
{
  "patch": {
    "current_feature": "user-authentication",
    "phase": "implement",
    "current_task_id": "AUTH-003"
  },
  "reason": "Starting implementation phase",
  "correlation_id": "optional-request-id",
  "skip_validation": false
}
```

#### Output Example
```json
{
  "changed": true,
  "state": {
    "current_feature": "user-authentication",
    "phase": "implement",
    "current_task_id": "AUTH-003",
    "updated_at": "2026-01-02T15:30:00Z"
  },
  "diff": {
    "phase": {"from": "spec", "to": "implement"}
  }
}
```

#### Usage Examples
```typescript
// Initialize new feature state
const result = await callTool('state_set', {
  patch: {
    current_feature: 'user-auth',
    phase: 'spec',
    current_task_id: 'AUTH-001'
  },
  reason: 'Starting authentication feature'
});

// Update single field
await callTool('state_set', {
  patch: { last_commit: 'a1b2c3d' },
  reason: 'Committed changes'
});
```

---

### state.get

Retrieve current state snapshot with optional history.

#### Input Schema
```json
{
  "include_history": true,
  "history_limit": 10
}
```

#### Output Example
```json
{
  "state": {
    "current_feature": "user-authentication",
    "phase": "implement",
    "current_task_id": "AUTH-003",
    "updated_at": "2026-01-02T15:30:00Z"
  },
  "history": [
    {
      "timestamp": "2026-01-02T15:20:00Z",
      "type": "state_advance",
      "diff": {"phase": {"from": "spec", "to": "implement"}}
    }
  ],
  "summary": "Active feature: user-authentication, phase: implement, task: AUTH-003"
}
```

#### Usage Examples
```typescript
// Get current state
const state = await callTool('state_get', {});
console.log(`Working on: ${state.state.current_feature}`);

// Get state with recent history
const withHistory = await callTool('state_get', {
  include_history: true,
  history_limit: 5
});
```

---

### state.advance

Advance to next task or phase (deterministic only, no inference).

#### Input Schema (Task)
```json
{
  "target": "next-task",
  "next_task_id": "AUTH-004",
  "reason": "Completed AUTH-003"
}
```

#### Input Schema (Phase)
```json
{
  "target": "next-phase",
  "next_phase": "verify",
  "reason": "Implementation complete"
}
```

#### Output Example
```json
{
  "changed": true,
  "advance_type": "task",
  "state": { /* updated state */ },
  "diff": {
    "current_task_id": {"from": "AUTH-003", "to": "AUTH-004"}
  }
}
```

#### Usage Examples
```typescript
// Advance to next task
await callTool('state_advance', {
  target: 'next-task',
  next_task_id: 'AUTH-004',
  reason: 'Completed AUTH-003'
});

// Advance to next phase
await callTool('state_advance', {
  target: 'next-phase',
  next_phase: 'implement',
  reason: 'Spec complete'
});
```

---

### state.reset

Reset state with confirmation gate and scoped operations.

#### Input Schema
```json
{
  "scope": "task",
  "confirm": true,
  "reason": "Task complete, clearing for next"
}
```

#### Scopes
- `all` - Reset everything to defaults
- `feature` - Reset current_feature, phase, task
- `phase` - Reset phase and task only
- `task` - Reset current_task_id only

#### Output Example
```json
{
  "changed": true,
  "scope": "task",
  "state": { /* updated state */ },
  "diff": {
    "current_task_id": {"from": "AUTH-003", "to": null}
  }
}
```

#### Usage Examples
```typescript
// Reset task (requires confirmation)
await callTool('state_reset', {
  scope: 'task',
  confirm: true,
  reason: 'Task complete'
});

// Full reset
await callTool('state_reset', {
  scope: 'all',
  confirm: true,
  reason: 'Feature complete, starting fresh'
});
```

---

### state.history

Query state history with filtering and defensive parsing.

#### Input Schema
```json
{
  "limit": 50,
  "since": "2026-01-02T00:00:00Z",
  "types": ["state_advance", "state_reset"],
  "feature": "user-authentication"
}
```

#### Output Example
```json
{
  "events": [
    {
      "timestamp": "2026-01-02T15:30:00Z",
      "type": "state_advance",
      "advance_type": "task",
      "reason": "Task completed",
      "diff": {"current_task_id": {"from": "AUTH-003", "to": "AUTH-004"}}
    }
  ],
  "count": 15,
  "limit": 50
}
```

#### Usage Examples
```typescript
// Query recent history
const history = await callTool('state_history', {
  limit: 20
});

// Query specific event types
const advances = await callTool('state_history', {
  types: ['state_advance'],
  limit: 50
});

// Query for specific feature
const featureHistory = await callTool('state_history', {
  feature: 'user-auth',
  since: '2026-01-01T00:00:00Z'
});
```

---

### State Management Workflow

```typescript
// 1. Start new feature
await callTool('state_set', {
  patch: {
    current_feature: 'api-v2',
    phase: 'spec',
    current_task_id: 'API-001'
  },
  reason: 'Starting API v2'
});

// 2. Advance through phases
await callTool('state_advance', {
  target: 'next-phase',
  next_phase: 'implement',
  reason: 'Spec complete'
});

// 3. Work through tasks
await callTool('state_advance', {
  target: 'next-task',
  next_task_id: 'API-002',
  reason: 'Completed API-001'
});

// 4. Reset when done
await callTool('state_reset', {
  scope: 'feature',
  confirm: true,
  reason: 'Feature deployed'
});

// 5. Review audit trail
const audit = await callTool('state_history', {
  feature: 'api-v2'
});
```

---

## Date & Time Tools

Documentation for date/time tools available separately.

---

## See Also
- [STATE-MANAGEMENT.md](./STATE-MANAGEMENT.md) - Complete state management guide
- [ENVELOPE-RESPONSE-STANDARD.md](./ENVELOPE-RESPONSE-STANDARD.md) - Response format standard
- [FRONTMATTER-SPEC.md](./FRONTMATTER-SPEC.md) - YAML frontmatter standard for dotbot artifacts
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture and design decisions
- [README.md](./README.md) - Project overview and getting started
