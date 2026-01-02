---
type: workflow
id: create-product-mission
version: "1.0"
category: planning
agent: product-planner
dependencies:
  - type: workflow
    id: gather-product-info
mcp_tools_used:
  - solution.info
  - solution.structure
artifacts_created:
  - type: product-mission
    location: .bot/product/mission.md
    frontmatter_required: true
---

# Create Product Mission Workflow

**Agent:** @.bot/agents/product-planner.md

This workflow guides you through creating a clear, focused product mission document.

## Purpose

A product mission serves as the north star for development decisions. It:
- Clarifies what problem you're solving
- Defines who you're solving it for
- Establishes success criteria
- Guides feature prioritization

## Prerequisites

- Understanding of the problem space
- Knowledge of target users
- Product concept or vision

## MCP Tool Response Handling

This workflow may call `solution.info` or `solution.structure` MCP tools. Follow `.bot/standards/global/workflow-mcp-instructions.md` for:
- How to handle envelope responses
- Checking status, errors, and data fields
- Proper error handling

## Artifact Frontmatter Requirements

When creating `mission.md`, **add YAML frontmatter** at the top. See `.bot/standards/global/workflow-mcp-instructions.md` for examples.

Required frontmatter:
```yaml
---
type: product-mission
id: [product-name]-mission
version: "1.0"
created_at: "[ISO-8601 timestamp]"
created_by: product-planner
related_artifacts:
  - .bot/product/roadmap.md
  - .bot/product/tech-stack.md
---
```

## Steps

### 1. Define the Vision

Write a 1-2 sentence vision statement:
- What is this product?
- What does it do?
- Why does it exist?

**Example:**
"A project management tool that helps remote teams coordinate work without meetings."

### 2. State the Problem

Clearly articulate the problem:
- What pain point exists?
- Who experiences this pain?
- How do they currently cope?
- Why existing solutions fall short?

### 3. Identify Target Users

Define primary and secondary user personas:
- Who are they?
- What do they need?
- What are their goals?
- What are their constraints?

### 4. Articulate Value Proposition

Explain why users should choose this:
- What unique value does it provide?
- How is it different from alternatives?
- What's the core benefit?

### 5. Establish Success Criteria

Define measurable success metrics:
- User acquisition goals
- Engagement metrics
- Business metrics
- Impact metrics

## Output Template

```markdown
# [Product Name] Mission

## Vision
[1-2 sentence vision statement]

## Problem Statement
[Detailed problem description]
[Who has this problem]
[Current solutions and their limitations]

## Target Users

### Primary Users
- **Who**: [Description]
- **Needs**: [Key needs]
- **Goals**: [What they want to achieve]

### Secondary Users
- **Who**: [Description]
- **Needs**: [Key needs]

## Core Value Proposition

[Clear statement of unique value]

**Why Choose This:**
- [Benefit 1]
- [Benefit 2]
- [Benefit 3]

## Success Criteria

**Year 1:**
- [Metric and target]
- [Metric and target]

**Year 2:**
- [Metric and target]
- [Metric and target]

## Principles

[Guiding principles for decision-making]
- [Principle 1]
- [Principle 2]
```

## Tips

- Keep vision concise and memorable
- Make problem statement specific
- Use real user personas if possible
- Be realistic about value proposition
- Choose measurable success criteria
- Revisit and update as you learn

