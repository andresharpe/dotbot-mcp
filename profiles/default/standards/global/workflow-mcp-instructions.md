# Workflow MCP Instructions

This document contains standard instructions for workflows that interact with MCP tools and create artifacts.

## MCP Tool Response Handling

When calling `solution.*` MCP tools, expect responses in envelope format:

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.info",
  "status": "ok|warning|error",
  "summary": "One-sentence summary of result",
  "data": { /* actual tool output */ },
  "warnings": [],
  "errors": [],
  "audit": {
    "timestamp": "ISO-8601",
    "duration_ms": 123,
    "source": "tool-name",
    "host": "hostname"
  }
}
```

**Always check these fields:**

1. **`status`** - Handle errors/warnings appropriately
   - `error`: Stop and display errors to user
   - `warning`: Continue but note warnings
   - `ok`: Proceed normally

2. **`errors` array** - Display to user if non-empty
   - Contains error objects with `code`, `message`, `details`

3. **`data` field** - Contains the actual tool output
   - This is where the real information lives

4. **`summary` field** - One-sentence result summary
   - Can be shown to user for context

5. **`audit` metadata** - For logging/debugging
   - Includes timing and source information

**Example handling:**

```powershell
$response = Invoke-SolutionInfo
if ($response.status -eq "error") {
    foreach ($error in $response.errors) {
        Write-Error "$($error.code): $($error.message)"
    }
    return
}
$solutionData = $response.data
```

## Artifact Frontmatter Requirements

When creating workflow artifacts (missions, roadmaps, specs, tasks, requirements, etc.), **always add YAML frontmatter** at the top of the file.

### Frontmatter Structure

```yaml
---
type: artifact-type
id: unique-identifier
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: agent-id
related_artifacts:
  - .bot/product/mission.md
  - .bot/product/roadmap.md
---
```

### Required Fields

- **`type`**: Artifact category (product-mission, roadmap, spec, tasks, requirements, tech-stack, verification-report)
- **`id`**: Unique identifier in kebab-case
- **`version`**: Semantic version (start with "1.0")
- **`created_at`**: ISO 8601 timestamp
- **`created_by`**: Agent identifier or "warp-agent"

### Optional Fields

- **`related_artifacts`**: Array of paths to related files
- **`spec_name`**: For spec-related artifacts
- **`phase`**: For phased artifacts (mvp, growth, maturity)

### Frontmatter Examples

**Product Mission:**
```yaml
---
type: product-mission
id: my-app-mission
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: product-planner
related_artifacts:
  - .bot/product/roadmap.md
  - .bot/product/tech-stack.md
---
```

**Roadmap:**
```yaml
---
type: roadmap
id: my-app-roadmap
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: product-planner
phase: mvp
related_artifacts:
  - .bot/product/mission.md
---
```

**Spec:**
```yaml
---
type: spec
id: user-authentication-spec
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: spec-writer
spec_name: 2026-01-02-user-authentication
related_artifacts:
  - .bot/specs/2026-01-02-user-authentication/planning/requirements.md
  - .bot/specs/2026-01-02-user-authentication/tasks.md
---
```

**Tasks:**
```yaml
---
type: tasks
id: user-authentication-tasks
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: tasks-list-creator
spec_name: 2026-01-02-user-authentication
related_artifacts:
  - .bot/specs/2026-01-02-user-authentication/spec.md
---
```

**Requirements:**
```yaml
---
type: requirements
id: user-authentication-requirements
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: spec-shaper
spec_name: 2026-01-02-user-authentication
related_artifacts:
  - .bot/specs/2026-01-02-user-authentication/spec.md
---
```

**Tech Stack:**
```yaml
---
type: tech-stack
id: my-app-tech-stack
version: "1.0"
created_at: "2026-01-02T13:00:00Z"
created_by: product-planner
related_artifacts:
  - .bot/product/mission.md
---
```

### Validation Steps

Before saving an artifact file:
1. ✓ Verify frontmatter is valid YAML
2. ✓ All required fields are present
3. ✓ Timestamps are in ISO 8601 format
4. ✓ Related artifact paths exist (if specified)
5. ✓ No syntax errors in frontmatter

### When NOT to Add Frontmatter

- README.md files (standard markdown files)
- Audit trail JSON files (not markdown)
- Verification reports (unless specified in workflow)
- Temporary or scratch files
