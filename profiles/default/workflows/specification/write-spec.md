---
type: workflow
id: write-spec
version: "1.0"
category: specification
agent: spec-writer
dependencies:
  - type: standard
    id: global/workflow-interaction
  - type: workflow
    id: research-spec
mcp_tools_used:
  - solution.info
  - solution.tech_stack
  - solution.standards.list
artifacts_created:
  - type: spec
    location: .bot/specs/[spec-name]/spec.md
    frontmatter_required: true
---

# Write Specification Workflow

**Agent:** @.bot/agents/spec-writer.md

**Interaction Standard:** When asking questions or gathering clarifications, follow `.bot/standards/global/workflow-interaction.md`

This workflow guides you through writing a detailed technical specification for a feature.

## MCP Tool Response Handling

This workflow may call `solution.info`, `solution.tech_stack`, or `solution.standards.list` MCP tools. Follow `.bot/standards/global/workflow-mcp-instructions.md` for envelope response handling.

## Artifact Frontmatter Requirements

When creating `spec.md`, **add YAML frontmatter** at the top:

```yaml
---
type: spec
id: [spec-name]-spec
version: "1.0"
created_at: "[ISO-8601 timestamp]"
created_by: spec-writer
spec_name: [spec-folder-name]
related_artifacts:
  - .bot/specs/[spec-name]/planning/requirements.md
  - .bot/specs/[spec-name]/tasks.md
---
```

## Prerequisites

- Clear understanding of the feature requirements
- Product roadmap or plan (if applicable)
- Tech stack decisions

## Steps

### 1. Initialize Spec Document

Create a spec document with the following structure:

```markdown
# [Feature Name] Specification

## Overview
Brief description of the feature and its purpose

## Goals
- What this feature aims to achieve
- Success criteria

## Non-Goals
- What this feature explicitly does NOT cover

## User Stories
- As a [user type], I want to [action] so that [benefit]

## Technical Design

### Architecture
High-level architecture decisions

### Data Models
Database schemas, data structures

### API Design
Endpoints, request/response formats

### UI/UX
Interface mockups, user flows

## Implementation Plan

### Phase 1
- Task breakdown
- Estimated effort

### Dependencies
- External dependencies
- Blockers

## Testing Strategy
- Unit tests
- Integration tests
- E2E tests

## Risks & Mitigation
- Identified risks
- Mitigation strategies

## Timeline
- Milestones
- Deadlines
```

### 2. Write Feature Overview

Write a clear, concise overview that explains:
- What the feature is
- Why it's needed
- Who it's for
- How it fits into the larger product

### 3. Define Goals & Non-Goals

**Goals**: Specific, measurable outcomes this feature should achieve

**Non-Goals**: Explicitly state what's out of scope to prevent scope creep

### 4. Document User Stories

Write user stories from the perspective of different user types:
- Focus on the "why" not just the "what"
- Include acceptance criteria
- Prioritize by importance

### 5. Design Technical Solution

#### Architecture
- Component diagrams
- System interactions
- Technology choices

#### Data Models
- Database schemas
- Relationships
- Indexes and constraints

#### API Design
- Endpoints and methods
- Request/response formats
- Authentication/authorization
- Error handling

#### UI/UX
- Wireframes or mockups
- User flows
- Accessibility considerations

### 6. Break Down Implementation

Create a phased implementation plan:
- Break into manageable tasks
- Estimate effort for each phase
- Identify dependencies
- Set milestones

### 7. Plan Testing Strategy

Define how the feature will be tested:
- Unit test coverage goals
- Integration test scenarios
- E2E test cases
- Performance testing (if applicable)

### 8. Identify Risks

Document potential risks and mitigation strategies:
- Technical risks
- Resource risks
- Timeline risks
- Dependencies on other teams

### 9. Review & Iterate

- Share spec with stakeholders
- Gather feedback
- Iterate on design
- Get approval before implementation

### 10. Verification (Optional)

Offer the user a thorough quality check:

```
Spec writing complete!

Would you like me to run a thorough verification check? This will:
- Verify requirements accuracy against original Q&A
- Check structural integrity of spec files
- Analyze visual alignment (if visuals exist)
- Validate reusability opportunities are leveraged
- Verify test writing limits (2-8 tests per task group)
- Generate a detailed verification report

Type 'verify' to run verification, or 'skip' to finish.
```

**If user chooses 'verify':** Follow `.bot/workflows/specification/verify-spec.md`

**If user chooses 'skip':** Proceed to output

## Output

A complete, detailed specification document that:
- Can be understood by all stakeholders
- Provides clear guidance for implementation
- Serves as a reference during development
- Documents decisions and trade-offs

## Tips

- Keep specs living documents - update them as you learn
- Be specific about what you're building
- Include diagrams where they help clarity
- Document "why" decisions were made
- Link to related specs or documentation

