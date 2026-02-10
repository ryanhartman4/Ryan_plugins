---
description: Get familiar with a new codebase by reading docs, exploring structure, and loading project skills
---

Orient yourself to this codebase by completing the following steps:

## 1. Read Documentation

Check if a `docs` folder exists in the current working directory (the project you're in right now). If it does, read through the documentation files to understand the project's purpose, architecture, and conventions.

## 2. Explore the Codebase

Familiarize yourself with the codebase structure. Use the Task tool with `subagent_type=Explore` to quickly map out:
- The main directories and their purposes
- The project's tech stack and dependencies
- Entry points and core modules

After the explore agent reports back, directly read these key files yourself so they're in your context for future work:
- README.md and/or CLAUDE.md at the root
- Main configuration files (package.json, pyproject.toml, Cargo.toml, etc.)
- Any architecture or design docs the agent identified

## 3. Check for Project-Specific Skills

Look for project-specific skills in `.claude/skills/` that may provide specialized instructions for working with this codebase. If found, review them to understand any custom workflows or conventions defined for this project.

After completing these steps, provide a brief summary of what you learned about the project.
