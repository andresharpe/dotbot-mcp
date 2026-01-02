# Envelope Response Standard

## Overview

All dotbot MCP tools return responses in a standardized **envelope format** that wraps the actual data with metadata, error handling, audit information, and optional intent suggestions. This provides consistency, observability, and improved error handling across all tools.

**Schema ID**: `dotbot-mcp-response@1`

## Rationale

**Problem**: Previous tool responses were inconsistent, lacked error handling standards, and provided no metadata for debugging or auditing.

**Solution**: The envelope format provides:
- **Consistency**: All tools use the same response structure
- **Error handling**: Structured errors and warnings with error codes
- **Observability**: Audit metadata for timing, source tracking, and correlation
- **Status computation**: Automatic determination of response health
- **Intent detection**: Optional suggestions for next actions

## Schema Specification

### Complete Structure

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.info",
  "version": "1.0.0",
  "status": "ok|warning|error",
  "summary": "One-sentence summary of operation result",
  "data": {
    "...": "Actual tool-specific output"
  },
  "warnings": [
    {
      "code": "WARNING_CODE",
      "message": "Warning description",
      "path": "Optional file path",
      "details": {}
    }
  ],
  "errors": [
    {
      "code": "ERROR_CODE",
      "message": "Error description",
      "path": "Optional file path",
      "details": {}
    }
  ],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 123,
    "source": ".bot/mcp/tools/solution-info/script.ps1",
    "host": "warp|claude-desktop|ci|null",
    "correlation_id": "optional-request-id",
    "write_to": "optional-file-written"
  },
  "intent": {
    "recommended_next": "solution.structure",
    "reason": "Why this action is suggested",
    "parameters": {}
  },
  "actions": [
    {
      "id": "action-id",
      "type": "suggestion",
      "label": "User-facing label",
      "reason": "Why user should take this action",
      "tool": "tool.name",
      "parameters": {}
    }
  ]
}
```

### Required Fields

All envelope responses **MUST** include:

#### `schema_id` (string)
- **Value**: `"dotbot-mcp-response@1"`
- **Purpose**: Identifies the envelope schema version
- **Validation**: Must be exactly this string

#### `tool` (string)
- **Value**: Tool name (e.g., `"solution.info"`, `"solution.health.check"`)
- **Purpose**: Identifies which tool generated the response
- **Validation**: Must match the actual tool name

#### `version` (string)
- **Value**: Tool version (e.g., `"1.0.0"`)
- **Purpose**: Tool versioning for compatibility
- **Format**: Semantic versioning (`major.minor.patch`)

#### `status` (string)
- **Value**: One of `"ok"`, `"warning"`, `"error"`
- **Purpose**: High-level health status of the operation
- **Computation**: Auto-computed based on `errors` and `warnings` arrays:
  - `"error"`: If `errors.length > 0`
  - `"warning"`: If `warnings.length > 0` AND `errors.length == 0`
  - `"ok"`: If both `errors.length == 0` AND `warnings.length == 0`

#### `summary` (string)
- **Value**: One-sentence human-readable summary
- **Purpose**: Quick understanding of operation result
- **Guidelines**:
  - Concise (one sentence)
  - Descriptive (what happened)
  - Specific (include key details like counts, names)
- **Examples**:
  - `"Axiome solution (dotbot 2.0.0, default profile) with product mission defined."`
  - `"Found 16 standards across 4 domains (global: 3, backend: 5, frontend: 4)."`
  - `"Registered 'Axiome.Bot' with alias 'be' and 3 tags."`

#### `data` (object)
- **Value**: Hashtable/object with tool-specific output
- **Purpose**: Contains the actual tool response data
- **Structure**: Tool-specific (see individual tool documentation)

#### `warnings` (array)
- **Value**: Array of warning objects (empty array if none)
- **Purpose**: Non-critical issues that didn't prevent operation
- **Structure**: See [Error and Warning Objects](#error-and-warning-objects)

#### `errors` (array)
- **Value**: Array of error objects (empty array if none)
- **Purpose**: Critical issues that prevented full operation
- **Structure**: See [Error and Warning Objects](#error-and-warning-objects)

#### `audit` (object)
- **Value**: Metadata about the operation execution
- **Purpose**: Observability, debugging, and audit trails
- **Required fields**:
  - `timestamp`: ISO 8601 UTC timestamp (e.g., `"2026-01-02T13:57:00Z"`)
  - `duration_ms`: Execution duration in milliseconds (integer)
  - `source`: Relative path to tool script (e.g., `".bot/mcp/tools/solution-info/script.ps1"`)

### Optional Fields

#### `audit.host` (string)
- **Value**: MCP host environment (`"warp"`, `"claude-desktop"`, `"ci"`, or `null`)
- **Purpose**: Track which MCP client is being used
- **Detection**: Auto-detected from environment variables

#### `audit.correlation_id` (string)
- **Value**: Request correlation ID for distributed tracing
- **Purpose**: Link related operations across multiple tool calls

#### `audit.write_to` (string)
- **Value**: Relative path to file written by the tool
- **Purpose**: Track which files were modified
- **Example**: `".bot/solution/projects.json"`

#### `intent` (object)
- **Value**: Suggested next action based on current state
- **Purpose**: Guide AI agents through workflows
- **Structure**:
  ```json
  {
    "recommended_next": "solution.structure",
    "reason": "Roadmap loaded. View solution structure to see projects.",
    "parameters": {}
  }
  ```

#### `actions` (array)
- **Value**: Array of actionable suggestions
- **Purpose**: Provide user/agent with next steps
- **Structure**:
  ```json
  [
    {
      "id": "view-structure",
      "type": "suggestion",
      "label": "View solution structure",
      "reason": "See updated project metadata",
      "tool": "solution.structure",
      "parameters": {}
    }
  ]
  ```

## Error and Warning Objects

Both `errors` and `warnings` arrays contain objects with this structure:

```json
{
  "code": "ERROR_CODE",
  "message": "Human-readable description",
  "path": "optional/file/path.md",
  "details": {
    "key": "Additional context"
  }
}
```

### Required Fields
- **`code`**: Error code from the [Error Code Catalog](#error-code-catalog)
- **`message`**: Human-readable error description

### Optional Fields
- **`path`**: File path related to the error (if applicable)
- **`details`**: Additional structured context

## Error Code Catalog

Standard error codes used across all dotbot tools:

### Solution Discovery Errors
- **`DOTBOT_NOT_FOUND`**: Not in a dotbot solution directory (no `.bot` folder found)
- **`STATE_FILE_INVALID`**: `.bot/.dotbot-state.json` is missing or invalid JSON

### Project Errors
- **`PROJECT_NOT_FOUND`**: Specified project name/alias not found
- **`ALIAS_CONFLICT`**: Duplicate project alias detected

### Registry Errors
- **`REGISTRY_PARSE_ERROR`**: Failed to parse `.bot/solution/projects.json`

### File Errors
- **`TECH_STACK_MISSING`**: `.bot/product/tech-stack.md` not found
- **`STANDARDS_NOT_FOUND`**: Standards directory empty or not found
- **`BROKEN_FILE_REFERENCE`**: Referenced file does not exist
- **`FRONTMATTER_MISSING`**: File missing YAML frontmatter
- **`FRONTMATTER_INVALID`**: YAML frontmatter syntax error or schema violation

### Validation Errors
- **`CIRCULAR_DEPENDENCY`**: Circular file references detected
- **`INVALID_PARAMETER`**: Required parameter missing or invalid type

### System Errors
- **`IO_ERROR`**: File system operation failed
- **`UNAUTHORIZED_OPERATION`**: Operation not permitted

## Status Computation

The `status` field is automatically computed based on the presence of errors and warnings:

```powershell
$status = if ($Errors.Count -gt 0) { "error" } 
          elseif ($Warnings.Count -gt 0) { "warning" } 
          else { "ok" }
```

### Status Meanings

**`"ok"`**:
- Operation completed successfully
- No errors or warnings
- Data is complete and valid

**`"warning"`**:
- Operation completed but with non-critical issues
- Data may be incomplete or have quality issues
- Action recommended but not required

**`"error"`**:
- Operation failed or partially failed
- Data may be missing, invalid, or unreliable
- Action required to resolve issues

## Implementation Guide

### PowerShell Implementation

Use the `New-EnvelopeResponse` helper from `solution-helpers.psm1`:

```powershell
function Invoke-SolutionInfo {
    param([hashtable]$Arguments)
    
    # Import helpers
    $helpersPath = Join-Path $PSScriptRoot '..\..\solution-helpers.psm1'
    Import-Module $helpersPath -Force
    
    # Start timer
    $timer = Start-ToolTimer
    
    try {
        # Find solution root
        $solutionRoot = Find-SolutionRoot
        if (-not $solutionRoot) {
            $duration = Get-ToolDuration -Stopwatch $timer
            return New-EnvelopeResponse `
                -Tool "solution.info" `
                -Version "1.0.0" `
                -Summary "Failed to retrieve solution info: not in a dotbot directory." `
                -Data @{} `
                -Errors @((New-ErrorObject -Code "DOTBOT_NOT_FOUND" -Message "Not in a dotbot solution directory")) `
                -Source ".bot/mcp/tools/solution-info/script.ps1" `
                -DurationMs $duration `
                -Host (Get-McpHost)
        }
        
        # Perform operation
        $result = @{
            solution = @{
                name = Split-Path $solutionRoot -Leaf
            }
        }
        
        # Build envelope
        $duration = Get-ToolDuration -Stopwatch $timer
        return New-EnvelopeResponse `
            -Tool "solution.info" `
            -Version "1.0.0" `
            -Summary "Axiome solution (dotbot 2.0.0, default profile)." `
            -Data $result `
            -Source ".bot/mcp/tools/solution-info/script.ps1" `
            -DurationMs $duration `
            -Host (Get-McpHost)
    }
    finally {
        Remove-Module solution-helpers -ErrorAction SilentlyContinue
    }
}
```

### Helper Functions

#### `Start-ToolTimer`
Starts a stopwatch for timing:
```powershell
$timer = Start-ToolTimer
```

#### `Get-ToolDuration`
Gets elapsed milliseconds:
```powershell
$duration = Get-ToolDuration -Stopwatch $timer
```

#### `New-ErrorObject`
Creates structured error:
```powershell
$error = New-ErrorObject `
    -Code "PROJECT_NOT_FOUND" `
    -Message "Project 'Foo' not found" `
    -Path ".bot/solution/projects.json" `
    -Details @{ searched_for = "Foo" }
```

#### `Get-McpHost`
Detects MCP host:
```powershell
$host = Get-McpHost  # Returns "warp", "claude-desktop", "ci", or null
```

## Usage Examples

### Example 1: Successful Operation

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.structure",
  "version": "1.0.0",
  "status": "ok",
  "summary": "Found 12 projects in Axiome solution.",
  "data": {
    "solution_root": "C:\\repos\\Axiome",
    "projects": [
      {
        "alias": "be",
        "name": "Axiome.Bot",
        "type": "dotnet-web"
      }
    ]
  },
  "warnings": [],
  "errors": [],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 45,
    "source": ".bot/mcp/tools/solution-structure/script.ps1",
    "host": "warp"
  }
}
```

### Example 2: Operation with Warnings

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.standards.list",
  "version": "1.0.0",
  "status": "warning",
  "summary": "Found 10 standards, but some files missing frontmatter.",
  "data": {
    "standards": [...]
  },
  "warnings": [
    {
      "code": "FRONTMATTER_MISSING",
      "message": "Standard file missing YAML frontmatter",
      "path": ".bot/standards/global/naming-conventions.md"
    }
  ],
  "errors": [],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 78,
    "source": ".bot/mcp/tools/solution-standards-list/script.ps1"
  }
}
```

### Example 3: Operation with Errors

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.project.register",
  "version": "1.0.0",
  "status": "error",
  "summary": "Failed to register project: project not found.",
  "data": {},
  "warnings": [],
  "errors": [
    {
      "code": "PROJECT_NOT_FOUND",
      "message": "Project 'NonExistentProject' not found in solution",
      "details": {
        "searched_name": "NonExistentProject",
        "available_projects": ["Axiome.Bot", "axiome-frontend"]
      }
    }
  ],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 12,
    "source": ".bot/mcp/tools/solution-project-register/script.ps1"
  }
}
```

### Example 4: With Intent Suggestion

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.info",
  "version": "1.0.0",
  "status": "ok",
  "summary": "Axiome solution with roadmap defined.",
  "data": {
    "solution": {...},
    "roadmap": {...}
  },
  "warnings": [],
  "errors": [],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 95,
    "source": ".bot/mcp/tools/solution-info/script.ps1"
  },
  "intent": {
    "recommended_next": "solution.structure",
    "reason": "Roadmap loaded. View solution structure to see projects aligned with roadmap phases.",
    "parameters": {}
  }
}
```

### Example 5: With Actions

```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.project.register",
  "version": "1.0.0",
  "status": "ok",
  "summary": "Registered 'Axiome.Bot' with alias 'be' and 3 tags.",
  "data": {
    "success": true,
    "project_name": "Axiome.Bot",
    "registered_metadata": {...}
  },
  "warnings": [],
  "errors": [],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 34,
    "source": ".bot/mcp/tools/solution-project-register/script.ps1",
    "write_to": ".bot/solution/projects.json"
  },
  "actions": [
    {
      "id": "view-structure",
      "type": "suggestion",
      "label": "View solution structure",
      "reason": "See updated project metadata in context",
      "tool": "solution.structure",
      "parameters": {}
    }
  ]
}
```

## AI Agent Guidelines

### Always Check Status

```typescript
const response = await callTool('solution_info', {});

if (response.status === 'error') {
  console.error('Operation failed:');
  response.errors.forEach(e => console.error(`  [${e.code}] ${e.message}`));
  return;
}

if (response.status === 'warning') {
  console.warn('Operation completed with warnings:');
  response.warnings.forEach(w => console.warn(`  [${w.code}] ${w.message}`));
}

// Use data
const solutionName = response.data.solution.name;
```

### Use Summary for Context

```typescript
// Show user what happened
console.log(response.summary);
// "Axiome solution (dotbot 2.0.0, default profile) with product mission defined."
```

### Follow Intent Suggestions

```typescript
if (response.intent) {
  console.log(`Suggested next: ${response.intent.recommended_next}`);
  console.log(`Reason: ${response.intent.reason}`);
  
  // Optionally follow suggestion
  const nextResponse = await callTool(
    response.intent.recommended_next,
    response.intent.parameters
  );
}
```

### Track Audit Metadata

```typescript
// Log for debugging
console.log(`Tool: ${response.tool}`);
console.log(`Duration: ${response.audit.duration_ms}ms`);
console.log(`Timestamp: ${response.audit.timestamp}`);

// Track file writes
if (response.audit.write_to) {
  console.log(`Modified: ${response.audit.write_to}`);
}
```

## Validation

Use `Assert-EnvelopeSchema` helper to validate responses:

```powershell
$response = Invoke-SolutionInfo -Arguments @{}
Assert-EnvelopeSchema -Response $response
# Throws if schema is invalid
```

## Migration from Old Format

### Before (Old Format)
```json
{
  "solution": {
    "name": "Axiome"
  }
}
```

### After (Envelope Format)
```json
{
  "schema_id": "dotbot-mcp-response@1",
  "tool": "solution.info",
  "version": "1.0.0",
  "status": "ok",
  "summary": "Axiome solution info retrieved.",
  "data": {
    "solution": {
      "name": "Axiome"
    }
  },
  "warnings": [],
  "errors": [],
  "audit": {
    "timestamp": "2026-01-02T13:57:00Z",
    "duration_ms": 45,
    "source": ".bot/mcp/tools/solution-info/script.ps1"
  }
}
```

**Key changes:**
1. Old data moved to `data` field
2. Added `schema_id`, `tool`, `version`
3. Added `status`, `summary`
4. Added `warnings`, `errors` arrays
5. Added `audit` metadata

## See Also

- [MCP-TOOLS.md](./MCP-TOOLS.md) - Complete tool reference with envelope examples
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [FRONTMATTER-SPEC.md](./FRONTMATTER-SPEC.md) - YAML frontmatter standard
- [solution-helpers.psm1](./profiles/default/mcp/solution-helpers.psm1) - Helper functions
