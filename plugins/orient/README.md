# Orient

Orient yourself to unfamiliar codebases by reading docs, exploring structure, and loading project skills.

## Installation

**Step 1:** Add the marketplace
```
/plugin marketplace add ryanhartman4/Ryan_plugins
```

**Step 2:** Install the plugin
```
/plugin install orient
```

**Step 3:** Restart Claude Code if prompted

**Step 4:** Start using the command
```
/orient
```

## What it Does

When you enter a new or unfamiliar codebase, `/orient` runs a structured exploration to get you up to speed quickly:

1. **Reads documentation** — Checks for a `docs/` folder and reads through available documentation
2. **Explores the codebase** — Maps out directories, tech stack, dependencies, entry points, and core modules using a dedicated explore agent
3. **Loads project skills** — Checks `.claude/skills/` for project-specific workflows and conventions

After completing these steps, it provides a brief summary of the project.

## How it Works

1. Checks for a `docs/` folder and reads through documentation files
2. Uses an explore agent to map directories, tech stack, dependencies, and entry points
3. Reads key files (README.md, CLAUDE.md, config files) directly into context
4. Checks `.claude/skills/` for project-specific workflows and conventions
5. Provides a brief summary of the project

## Commands

### `/orient`
Get familiar with a new codebase by reading docs, exploring structure, and loading project skills.

**Use when:** You're onboarding to a new project, returning after time away, or starting a new session and want full project context loaded.

**How it works:**
1. Reads documentation from `docs/` if available
2. Explores codebase structure with a dedicated explore agent
3. Loads project-specific skills from `.claude/skills/`
4. Summarizes what was learned about the project

## When to Use

- Onboarding to a new project
- Returning to a codebase after time away
- Starting a new Claude Code session and wanting full project context loaded
