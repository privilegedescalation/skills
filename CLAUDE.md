# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **Privileged Escalation org-level repository**. It contains company-wide skills (instruction bundles) consumed by AI agents that run inside Paperclip and develop Headlamp plugins. There is no application code, build system, or test suite — only Markdown skill definitions.

## Structure

- `skills/` — Company skill definitions, each in its own directory with a `SKILL.md` file
  - `skills/safety/SKILL.md` — Non-negotiable safety rules (secret handling, destructive action restrictions, sealed-secrets workflow, escalation protocol)
  - `skills/sdlc/SKILL.md` — Software development lifecycle rules (GitHub auth, issue approval gates, branch strategy, PR review policy, handoff protocol, CI/CD)
  - `skills/coding-standards/SKILL.md` — Headlamp plugin development conventions (stack, commands, registration API, shared libraries)

## Skill File Format

Each skill is a Markdown file with YAML frontmatter containing `name` and `description` fields:

```markdown
---
name: skill-name
description: >
  One-line description of what the skill covers.
---

# Skill Title

Content...
```

## Skill Loading Order

Skills are loaded by Paperclip in this order: `safety` → `sdlc` → `coding-standards`. Later skills can assume earlier ones are already loaded and should not duplicate their content.
