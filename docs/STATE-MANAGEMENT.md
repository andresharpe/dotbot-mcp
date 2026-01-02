# State Management

## Overview

State management tools provide deterministic, repo-native tracking of feature development progression in dotbot solutions. These tools coordinate **intent, scope, and progression** while remaining separate from workflows, agents, and standards.

**Key Principle**: State tools are an **integration/coordination layer only** - they track *what* and *where* you are in development, not *how* to do the work.

## State File Structure

```
.bot/state/
├── state.json           # Authoritative machine state (atomic writes)
├── history.ndjson       # Append-only event log
└── phase-order.json     # Optional phase progression sequence
```

### state.json

The authoritative source of truth for current development state:

```json
{
  "current_feature": "user-authentication",
  "phase": "implement",
  "phase_index": 2,
  "current_task_id": "AUTH-003",
  "active_branch": "feature/user-auth",
  "worktree_path": "/path/to/worktree",
  "last_commit": "a1b2c3d",
  "updated_at": "2026-01-02T15:30:00Z",
  "notes": "Implementing OAuth2 flow",
  "locks": {}
}
```

### history.ndjson

Append-only event log (one JSON object per line):

```json
{"timestamp":"2026-01-02T15:00:00Z","type":"state_init","diff":{}}
{"timestamp":"2026-01-02T15:10:00Z","type":"state_set","reason":"Start feature","diff":{"current_feature":{"from":null,"to":"user-authentication"}}}
{"timestamp":"2026-01-02T15:20:00Z","type":"state_advance","advance_type":"phase","diff":{"phase":{"from":"spec","to":"implement"}}}
{"timestamp":"2026-01-02T15:30:00Z","type":"state_advance","advance_type":"task","diff":{"current_task_id":{"from":"AUTH-002","to":"AUTH-003"}}}
```

### phase-order.json (Optional)

Defines progression sequence for phase advancement:

```json
{
  "phases": ["spec", "tasks", "implement", "verify", "deploy"],
  "description": "Standard feature development lifecycle"
}
```

## State Model

### Field Definitions

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `current_feature` | string\|null | Feature being developed | Freeform text |
| `phase` | string | Current development phase | enum: spec, tasks, implement, verify, deploy |
| `phase_index` | int\|null | Numeric phase index (optional) | Non-negative integer |
| `current_task_id` | string\|null | Active task identifier | Pattern: `^[A-Z0-9-]+$` |
| `active_branch` | string\|null | Git branch name | Freeform text |
| `worktree_path` | string\|null | Git worktree path | Valid path |
| `last_commit` | string\|null | Latest commit SHA | 7-40 hex chars |
| `updated_at` | string | Last update timestamp | ISO 8601 UTC |
| `notes` | string\|array\|null | Freeform notes | Any type |
| `locks` | object\|null | Reserved for future use | Object |

### Phase Conventions

| Phase | Purpose | Typical Activities |
|-------|---------|-------------------|
| `spec` | Specification | Requirements gathering, design docs, API contracts |
| `tasks` | Task Planning | Break down work, estimate effort, assign tasks |
| `implement` | Implementation | Write code, unit tests, documentation |
| `verify` | Verification | Integration testing, code review, QA |
| `deploy` | Deployment | Release prep, deployment, monitoring |

**Note**: These are conventions, not enforced rules. Tools validate only that phase is in the enum, not workflow adherence.

### Task ID Conventions

Task IDs must match pattern: `^[A-Z0-9-]+$`

**Examples**:
- `FEATURE-001`, `FEATURE-002` (sequential)
- `AUTH-IMPL`, `AUTH-TEST` (semantic)
- `TASK-123`, `BUG-456` (typed)
- `A`, `B`, `C` (simple)

**Invalid**: `task-01` (lowercase), `feature_01` (underscore), `task#01` (special char)

## State Tools

### state-set

Initialize or update state fields with validation and history tracking.

**Purpose**: Create/modify state with atomic writes and audit trail.

**Input**:
```json
{
  "patch": {
    "current_feature": "user-authentication",
    "phase": "spec",
    "current_task_id": "AUTH-001"
  },
  "reason": "Starting authentication feature",
  "correlation_id": "optional-request-id",
  "skip_validation": false
}
```

**Features**:
- Auto-initializes state if missing
- Validates phase enum and task ID format
- Computes diff and appends to history
- Returns "No changes" if values unchanged
- Atomic writes with temp file + rename

**Output**:
```json
{
  "changed": true,
  "state": { /* full state */ },
  "diff": {
    "current_feature": {"from": null, "to": "user-authentication"},
    "phase": {"from": null, "to": "spec"}
  },
  "paths": {
    "state_file": ".bot/state/state.json",
    "history_file": ".bot/state/history.ndjson"
  }
}
```

### state-get

Retrieve current state snapshot with optional history.

**Purpose**: Read state for resumption, status checks, or debugging.

**Input**:
```json
{
  "include_history": true,
  "history_limit": 10
}
```

**Output**:
```json
{
  "state": {
    "current_feature": "user-authentication",
    "phase": "implement",
    "current_task_id": "AUTH-003",
    "updated_at": "2026-01-02T15:30:00Z"
  },
  "history": [
    {"timestamp": "2026-01-02T15:20:00Z", "type": "state_advance"}
  ],
  "paths": {
    "state_file": ".bot/state/state.json",
    "history_file": ".bot/state/history.ndjson"
  },
  "summary": "Active feature: user-authentication, phase: implement, task: AUTH-003"
}
```

### state-advance

Advance to next task or phase (deterministic only).

**Purpose**: Progress through development lifecycle without inference.

**Input (Task Advancement)**:
```json
{
  "target": "next-task",
  "next_task_id": "AUTH-004",
  "reason": "Completed AUTH-003",
  "correlation_id": "optional"
}
```

**Input (Phase Advancement)**:
```json
{
  "target": "next-phase",
  "next_phase": "verify",
  "reason": "Implementation complete"
}
```

**Or (with phase-order.json)**:
```json
{
  "target": "next-phase",
  "reason": "Ready for next phase"
}
```

**Features**:
- Requires explicit next_task_id or next_phase
- Can use phase-order.json for automatic phase progression
- Validates task ID format and phase values
- Auto-increments phase_index if present
- No state inference from git/filesystem

**Output**:
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

### state-reset

Reset state with confirmation gate and scoped operations.

**Purpose**: Clear state fields for fresh start or task completion.

**Input**:
```json
{
  "scope": "task",
  "confirm": true,
  "reason": "Task complete, clearing for next",
  "correlation_id": "optional"
}
```

**Scopes**:
- `all`: Reset everything to defaults
- `feature`: Reset current_feature, phase, task
- `phase`: Reset phase and task only
- `task`: Reset current_task_id only

**Confirmation Gate**:
- `confirm=false`: Returns warning without mutation
- `confirm=true`: Requires `reason` parameter

**Output (without confirmation)**:
```json
{
  "confirmation_required": true,
  "scope": "task"
}
```

**Output (with confirmation)**:
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

### state-history

Query state history with filtering.

**Purpose**: Audit trail analysis, debugging, and workflow introspection.

**Input**:
```json
{
  "limit": 50,
  "since": "2026-01-02T00:00:00Z",
  "types": ["state_advance", "state_reset"],
  "feature": "user-authentication"
}
```

**Features**:
- Filter by limit (default 50, max 500)
- Filter by timestamp (ISO 8601)
- Filter by event types
- Filter by feature name
- Defensive NDJSON parsing (skips invalid lines)
- Returns events newest-first

**Output**:
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
  "limit": 50,
  "invalid_lines_skipped": 0
}
```

## Usage Patterns

### Pattern 1: Starting a New Feature

```bash
# Initialize feature state
state-set --patch '{"current_feature":"user-auth","phase":"spec","current_task_id":"AUTH-001"}' --reason "Starting authentication feature"

# Get current state
state-get

# Advance through phases
state-advance --target next-phase --next-phase tasks --reason "Spec complete"
state-advance --target next-phase --next-phase implement --reason "Tasks defined"

# Advance through tasks
state-advance --target next-task --next-task-id AUTH-002 --reason "Completed AUTH-001"
```

### Pattern 2: Resuming After Interruption

```bash
# Check where we left off
state-get --include-history true --history-limit 5

# Continue from current state
state-advance --target next-task --next-task-id AUTH-005 --reason "Resuming work"
```

### Pattern 3: Auditing Progress

```bash
# Query recent changes
state-history --limit 20

# Query specific event types
state-history --types '["state_advance"]' --limit 50

# Query for specific feature
state-history --feature "user-auth" --since "2026-01-01T00:00:00Z"
```

### Pattern 4: Resetting State

```bash
# Preview reset (confirmation required warning)
state-reset --scope task --confirm false

# Execute reset
state-reset --scope task --confirm true --reason "Task complete, ready for next"

# Full reset
state-reset --scope all --confirm true --reason "Feature complete, starting fresh"
```

## Safety & Validation

### Deterministic Design

**State tools NEVER infer state from**:
- Git branches or commits
- File system state
- Conversation history
- Naming conventions

**State is ONLY changed by**:
- Explicit state-set calls
- Explicit state-advance calls
- Explicit state-reset calls

### Atomic Writes

All state mutations use atomic writes:
1. Write to `.bot/state/state.json.tmp`
2. Rename to `.bot/state/state.json`

This prevents corruption if process is interrupted.

### Validation

**state-set validation** (opt-in, default enabled):
- `phase`: Must be in enum (spec, tasks, implement, verify, deploy)
- `current_task_id`: Must match pattern `^[A-Z0-9-]+$`
- `last_commit`: Must be 7-40 hex characters

**state-advance validation**:
- `next_task_id`: Must match pattern `^[A-Z0-9-]+$`
- `next_phase`: Must be in enum
- `phase-order.json`: Must be valid JSON array

**Skip validation** (advanced use):
```json
{
  "patch": {"custom_field": "any value"},
  "skip_validation": true
}
```

### Confirmation Gates

**state-reset** requires explicit confirmation:
- `confirm=false`: Returns warning, does not mutate
- `confirm=true`: Requires `reason` parameter

This prevents accidental state loss.

## Integration with Workflows

### Layering Principle

State tools are an **integration layer**:

```
┌─────────────────────────────────────┐
│         Workflows                   │  ← HOW work is done
│  (process steps, quality gates)     │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      State Management               │  ← WHAT/WHERE tracking
│  (intent, scope, progression)       │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Standards                    │  ← Quality rules
│  (coding patterns, conventions)     │
└─────────────────────────────────────┘
```

### Workflow Coordination

Workflows use state tools for:
- **Resumption**: Check state-get to know where work left off
- **Progression**: Call state-advance when phases/tasks complete
- **Branching**: Read state to determine which workflow path to take
- **Audit**: Query state-history for debugging or reporting

**Workflows remain authoritative for**:
- Process steps
- Quality gates
- Code generation
- Testing strategies

### Agent Coordination

Agents use state tools for:
- **Context**: Know what feature/phase is active
- **Handoffs**: Pass state between agent roles
- **Coordination**: Avoid duplicate work

**Agents remain authoritative for**:
- Persona and tone
- Communication style
- Code review comments
- User interaction

## Best Practices

### DO ✅

- Use state tools to track **intent and progression**
- Update state when phases/tasks change
- Query history for debugging
- Use correlation_id for related operations
- Provide meaningful reason strings
- Use confirmation gates for resets

### DON'T ❌

- Infer state from git branches
- Embed workflow logic in state tools
- Duplicate standards content in state
- Skip validation without good reason
- Reset without confirmation
- Mix state tracking with execution logic

## Error Handling

All state tools return envelope responses with structured errors:

```json
{
  "status": "error",
  "errors": [
    {
      "code": "INVALID_PHASE",
      "message": "Phase must be one of: spec, tasks, implement, verify, deploy",
      "details": {"provided": "invalid-phase"}
    }
  ]
}
```

See [ENVELOPE-RESPONSE-STANDARD.md](./ENVELOPE-RESPONSE-STANDARD.md) for complete error catalog.

## Examples

### Full Feature Lifecycle

```bash
# 1. Initialize
state-set --patch '{"current_feature":"api-v2","phase":"spec"}' --reason "Starting API v2"

# 2. Define tasks
state-advance --target next-phase --next-phase tasks --reason "Spec complete"
state-set --patch '{"current_task_id":"API-001"}' --reason "Starting first task"

# 3. Implement
state-advance --target next-phase --next-phase implement --reason "Tasks defined"

# Work through tasks
state-advance --target next-task --next-task-id API-002 --reason "Completed API-001"
state-advance --target next-task --next-task-id API-003 --reason "Completed API-002"

# 4. Verify
state-advance --target next-phase --next-phase verify --reason "Implementation done"

# 5. Deploy
state-advance --target next-phase --next-phase deploy --reason "Tests passed"

# 6. Complete
state-reset --scope feature --confirm true --reason "Feature deployed successfully"

# 7. Audit trail
state-history --feature "api-v2"
```

## Related Documentation

- [ENVELOPE-RESPONSE-STANDARD.md](./ENVELOPE-RESPONSE-STANDARD.md) - Response format
- [MCP-TOOLS.md](./MCP-TOOLS.md) - All MCP tools
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [STATE-IMPLEMENTATION-STATUS.md](./STATE-IMPLEMENTATION-STATUS.md) - Implementation details
