# YAML Frontmatter Specification for Dotbot Artifacts

## Overview

All dotbot artifacts (workflows, agents, standards, commands, product documents) **MUST** include structured YAML frontmatter at the top of the file. This makes artifacts both **human-readable** (markdown content) and **machine-parseable** (YAML metadata).

## Rationale

**Problem**: Current dotbot artifacts are freeform markdown with inconsistent structure. MCP tools must use fragile regex parsing, and there's no reliable way to discover dependencies or validate completeness.

**Solution**: YAML frontmatter provides:
- **Machine-readability**: Structured metadata for AI agents and tooling
- **Dependency tracking**: Explicit file references for integrity checks
- **Validation**: Schema-based validation of artifact completeness
- **Discoverability**: Tools can scan and index artifacts automatically
- **Backward compatibility**: Markdown content remains human-readable

## General Format

```markdown
---
# YAML frontmatter here
type: workflow
id: my-workflow
version: 1.0
---

# Workflow Title

Markdown content here...
```

### Rules
1. Frontmatter **MUST** be at the very top of the file
2. Frontmatter **MUST** start and end with `---`
3. Frontmatter **MUST** be valid YAML
4. Frontmatter **MUST** include `type`, `id`, and `version` fields
5. Markdown content follows after the closing `---`

---

## Workflow Frontmatter

Workflows define structured processes for AI agents to follow.

### Schema
```yaml
---
type: workflow                          # REQUIRED: Must be "workflow"
id: gather-product-info                 # REQUIRED: Unique identifier (kebab-case)
category: planning                      # REQUIRED: planning|specification|implementation|verification
agent: product-planner                  # REQUIRED: Primary agent ID
dependencies:                           # OPTIONAL: List of file dependencies
  - type: agent                         # agent|standard|workflow
    file: .bot/agents/product-planner.md
  - type: standard
    file: .bot/standards/global/workflow-interaction.md
outputs:                                # OPTIONAL: Expected outputs
  - type: audit                         # audit|file|state
    location: .bot/audit/workflows/gather-product-info/
  - type: file
    location: .bot/product/mission.md
questions: 4                            # OPTIONAL: Number of questions asked
estimated_duration: 15min               # OPTIONAL: Estimated completion time
version: 1.0                            # REQUIRED: Semantic version
---
```

### Required Fields
- `type`: Must be `"workflow"`
- `id`: Unique identifier in kebab-case (e.g., `gather-product-info`)
- `category`: One of: `planning`, `specification`, `implementation`, `verification`
- `agent`: Primary agent ID that executes the workflow
- `version`: Semantic version (e.g., `1.0`, `2.1.3`)

### Optional Fields
- `dependencies`: List of files this workflow depends on
  - `type`: `agent`, `standard`, or `workflow`
  - `file`: Relative path from solution root
- `outputs`: Expected outputs from the workflow
  - `type`: `audit`, `file`, or `state`
  - `location`: Path to output location
- `questions`: Number of questions the workflow asks the user
- `estimated_duration`: Estimated time (e.g., `15min`, `1h`, `30min`)

### Example
```yaml
---
type: workflow
id: implement-feature
category: implementation
agent: feature-implementer
dependencies:
  - type: agent
    file: .bot/agents/feature-implementer.md
  - type: standard
    file: .bot/standards/global/naming-conventions.md
  - type: standard
    file: .bot/standards/backend/dotnet-api-design.md
outputs:
  - type: file
    location: src/
  - type: audit
    location: .bot/audit/workflows/implement-feature/
questions: 3
estimated_duration: 2h
version: 1.0
---
```

---

## Agent Frontmatter

Agents are AI specialists with specific roles and expertise.

### Schema
```yaml
---
type: agent                             # REQUIRED: Must be "agent"
id: product-planner                     # REQUIRED: Unique identifier (kebab-case)
role: Product Planning Specialist       # REQUIRED: Human-readable role
expertise:                              # REQUIRED: List of expertise areas
  - Product strategy
  - User research
  - Market analysis
used_by:                                # OPTIONAL: Workflows that use this agent
  - .bot/workflows/planning/gather-product-info.md
  - .bot/workflows/planning/create-roadmap.md
version: 1.0                            # REQUIRED: Semantic version
---
```

### Required Fields
- `type`: Must be `"agent"`
- `id`: Unique identifier in kebab-case
- `role`: Human-readable role description
- `expertise`: List of expertise areas (strings)
- `version`: Semantic version

### Optional Fields
- `used_by`: List of workflows that use this agent (file paths)

### Example
```yaml
---
type: agent
id: feature-implementer
role: Feature Implementation Specialist
expertise:
  - Software architecture
  - Code generation
  - Test-driven development
  - API design
used_by:
  - .bot/workflows/implementation/implement-feature.md
  - .bot/workflows/implementation/refactor-code.md
version: 1.0
---
```

---

## Standard Frontmatter

Standards define coding conventions and best practices.

### Schema
```yaml
---
type: standard                          # REQUIRED: Must be "standard"
id: workflow-interaction                # REQUIRED: Unique identifier (kebab-case)
domain: global                          # REQUIRED: global|backend|frontend|testing|security
applies_to:                             # REQUIRED: What this standard applies to
  - all-workflows
  - dotnet-web
version: 1.0                            # REQUIRED: Semantic version
last_updated: 2025-11-20                # OPTIONAL: Last update date (ISO 8601)
---
```

### Required Fields
- `type`: Must be `"standard"`
- `id`: Unique identifier in kebab-case
- `domain`: One of: `global`, `backend`, `frontend`, `testing`, `security`, `deployment`
- `applies_to`: List of contexts where this standard applies (e.g., `all-workflows`, `dotnet-web`, `nextjs-app`)
- `version`: Semantic version

### Optional Fields
- `last_updated`: Last update date in ISO 8601 format (`YYYY-MM-DD`)

### Example
```yaml
---
type: standard
id: dotnet-api-design
domain: backend
applies_to:
  - dotnet-web
  - dotnet-library
version: 1.0
last_updated: 2025-11-20
---
```

---

## Command Frontmatter

Commands are user-facing shortcuts that trigger workflows.

### Schema
```yaml
---
type: command                           # REQUIRED: Must be "command"
id: start-feature                       # REQUIRED: Unique identifier (kebab-case)
category: feature                       # REQUIRED: feature|planning|implementation
triggers_workflow: .bot/workflows/implementation/start-feature.md  # REQUIRED: Workflow path
parameters:                             # OPTIONAL: Command parameters
  - name: feature_name
    required: true
version: 1.0                            # REQUIRED: Semantic version
---
```

### Required Fields
- `type`: Must be `"command"`
- `id`: Unique identifier in kebab-case
- `category`: One of: `feature`, `planning`, `implementation`, `verification`
- `triggers_workflow`: Path to workflow file that this command triggers
- `version`: Semantic version

### Optional Fields
- `parameters`: List of command parameters
  - `name`: Parameter name
  - `required`: Boolean indicating if parameter is required

### Example
```yaml
---
type: command
id: start-feature
category: feature
triggers_workflow: .bot/workflows/implementation/implement-feature.md
parameters:
  - name: feature_name
    required: true
  - name: branch_name
    required: false
version: 1.0
---
```

---

## Product Artifact Frontmatter

Product artifacts include mission, roadmap, and tech stack documents.

### Schema
```yaml
---
type: product-mission                   # REQUIRED: product-mission|product-roadmap|product-tech-stack
version: 1.0                            # REQUIRED: Semantic version
last_updated: 2025-11-20                # OPTIONAL: Last update date (ISO 8601)
authors:                                # OPTIONAL: List of authors
  - AI Agent
  - User Name
---
```

### Required Fields
- `type`: One of: `product-mission`, `product-roadmap`, `product-tech-stack`
- `version`: Semantic version

### Optional Fields
- `last_updated`: Last update date in ISO 8601 format
- `authors`: List of authors/contributors

### Example
```yaml
---
type: product-mission
version: 1.0
last_updated: 2025-11-20
authors:
  - Product Planner Agent
  - Andre Marquis
---
```

---

## Validation Rules

### Schema Validation
1. **Type-specific fields**: Each `type` has required and optional fields
2. **Field types**: 
   - Strings: `id`, `role`, `domain`, `category`
   - Lists: `expertise`, `dependencies`, `outputs`, `applies_to`
   - Integers: `questions`
   - Dates: `last_updated` (ISO 8601)
3. **Enum values**: Some fields have restricted values (see schemas above)

### Dependency Validation
1. **File references**: All `file` paths in `dependencies` must exist
2. **Bidirectional consistency**: If workflow depends on agent, agent's `used_by` should include workflow
3. **No circular dependencies**: Workflows cannot depend on each other circularly

### ID Naming Conventions
1. Use **kebab-case**: `my-workflow-name`, not `MyWorkflowName` or `my_workflow_name`
2. Be **descriptive**: `gather-product-info` not `gpinfo`
3. Be **unique**: No two artifacts can have the same `id` within their type

---

## Tooling Support

### Validation Tool
Use `solution.health.check` with `comprehensive` level to validate frontmatter:
```typescript
const health = await callTool('solution_health_check', {
  check_level: 'comprehensive'
});

// Check for frontmatter issues
const frontmatterCategory = health.checks.find(c => c.category === 'frontmatter-validation');
if (frontmatterCategory.status !== 'pass') {
  console.error('Frontmatter validation failed');
}
```

### Parsing in PowerShell
```powershell
# Import helpers
Import-Module ./solution-helpers.psm1

# Parse frontmatter from file
$frontmatter = Parse-ArtifactFrontmatter -FilePath '.bot/workflows/my-workflow.md'

# Access fields
Write-Host "Type: $($frontmatter.type)"
Write-Host "ID: $($frontmatter.id)"
Write-Host "Dependencies: $($frontmatter.dependencies.Count)"

# Validate schema
$isValid = Validate-FrontmatterSchema -Frontmatter $frontmatter -Type 'workflow'
```

---

## Migration Guide

### Adding Frontmatter to Existing Files

1. **Identify artifact type**: Is it a workflow, agent, standard, or command?
2. **Create frontmatter block**: Add `---` at top of file
3. **Fill required fields**: `type`, `id`, `version`
4. **Add optional fields**: Dependencies, outputs, etc.
5. **Close frontmatter**: Add `---` after metadata
6. **Validate**: Run `solution.health.check` to verify

### Example Migration
**Before:**
```markdown
# Gather Product Information

This workflow helps gather product requirements...
```

**After:**
```markdown
---
type: workflow
id: gather-product-info
category: planning
agent: product-planner
dependencies:
  - type: agent
    file: .bot/agents/product-planner.md
version: 1.0
---

# Gather Product Information

This workflow helps gather product requirements...
```

---

## Best Practices

1. **Always include frontmatter**: Even for new files - don't skip it
2. **Keep dependencies up to date**: When referencing other files, add them to `dependencies`
3. **Use semantic versioning**: Increment version when making significant changes
4. **Document used_by relationships**: Help maintain bidirectional links
5. **Validate regularly**: Run health checks to catch issues early
6. **Be consistent**: Follow naming conventions across all artifacts

---

## See Also
- [MCP-TOOLS.md](./MCP-TOOLS.md) - Documentation for `solution.*` tools
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [solution.health.check](./MCP-TOOLS.md#solutionhealthcheck) - Frontmatter validation tool
