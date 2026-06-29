# Available Skills

This document lists the interactive skills available in this repository. Skills are project-local agent workflows that ship with the repo and work in any Cursor (or Claude Code) agent that opens this workspace.

## Where Skills Live

Skills live under [`.cursor/skills/`](../.cursor/skills/) at the repository root. Each skill is a folder containing a `SKILL.md` file with YAML frontmatter so the agent runtime can discover and surface it on relevant prompts.

```
.cursor/skills/
├── readme-generate/
│   └── SKILL.md
└── prepare-opensource/
    └── SKILL.md
```

Because they're committed to the repo, every contributor and CI agent gets the same workflows — there is no per-machine setup.

## What Are Skills?

Skills are interactive workflows that:

- Guide you step-by-step through complex processes
- Ask clarifying questions when needed
- Validate outputs against the project's standards
- Reference the same `.cursor/rules/*.mdc` files that already gate code review

## How to Invoke

In Cursor's Agent chat, type `/` and select the skill, or describe the task:

```
/readme-generate
```

```
"help me generate a readme"
```

In Claude Code, the same `/` invocation works once the skill files are visible to the runtime. A description that matches the skill's `description:` frontmatter will also auto-trigger it.

---

## 📚 Documentation Skills

### `/readme-generate`

**Generate or update OSPO-compliant README files**

**When to use**:

- Creating a new README from scratch
- Updating existing README sections
- Ensuring OSPO compliance requirements
- Following Salesforce accelerator documentation standards

**What it does**:

1. Asks for project details (name, description, features, components)
2. Generates a complete README following the enterprise template
3. Ensures three installation paths (GitHub Deploy, Workbench, CLI)
4. Adds proper badges, architecture diagrams, and tables
5. Includes the OSPO-compliant disclaimer
6. Validates required sections and structure

**Example invocations**:

- `/readme-generate`
- "generate a readme"
- "update readme with new features"
- "make readme ospo compliant"

**Skill file**: [`.cursor/skills/readme-generate/SKILL.md`](../.cursor/skills/readme-generate/SKILL.md)
**Underlying rule**: [`Accelerator README.mdc`](../.cursor/rules/Accelerator%20README.mdc)

**Interactive prompts**:

- Project name?
- GitHub username/organization?
- Repository name?
- Project tagline/description?
- Key features by category?
- Technical components?
- Prerequisites?

**Output**: Complete or updated `README.md` at repository root.

---

### `/prepare-opensource`

**Validate OSPO compliance and prepare for open source release**

**When to use**:

- Preparing the accelerator for public GitHub release
- Validating OSPO compliance requirements
- Before submitting an OSPO approval request
- Generating missing compliance files

**What it does**:

1. Checks for required files at root level (`LICENSE`, `CONTRIBUTING`, `CODE_OF_CONDUCT`, `SECURITY`)
2. Generates missing files from the Salesforce OSS templates
3. Validates existing file content
4. Scans for non-public internal references before release
5. Adds copyright headers to source files (`.cls`, `.js`, `.html`, `.css`)
6. Creates a detailed compliance checklist
7. Guides through the approval process

**Example invocations**:

- `/prepare-opensource`
- "prepare for open source"
- "check ospo compliance"
- "validate compliance files"
- "ready for github"

**Skill file**: [`.cursor/skills/prepare-opensource/SKILL.md`](../.cursor/skills/prepare-opensource/SKILL.md)
**Underlying rule**: [`OSPO-Comppliance.mdc`](../.cursor/rules/OSPO-Comppliance.mdc)

**Interactive prompts**:

- Copyright year? (default: current year)
- Governance model? (Community / Salesforce Sponsored / Published)
- Add copyright headers to {X} files?
- Create CODEOWNERS file?
- Review internal references found?

**Output**:

- `LICENSE.txt` (Apache 2.0)
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- Copyright headers in source files
- Compliance checklist

**Critical requirement**: All files must be at root level (not in subdirectories).

---

## 🎯 Skills vs Rules

### Rules (Passive Guidelines)

- Located in [`.cursor/rules/`](../.cursor/rules/)
- Always available as context
- Applied automatically based on file type
- Inform coding standards and best practices
- Examples: LWC best practices, Apex patterns, testing standards

### Skills (Active Workflows)

- Located in [`.cursor/skills/`](../.cursor/skills/) (project-local)
- Invoked explicitly by user (`/skill-name`) or auto-triggered by description match
- Interactive step-by-step processes
- Ask questions and validate input
- Examples: `/readme-generate`, `/prepare-opensource`

**Relationship**: Skills reference the underlying rules but provide interactive workflows for complex multi-step tasks.

---

## 📖 Skill Reference Table

| Skill                 | Purpose                        | When to Use                     | Reference Rule                                                        |
| --------------------- | ------------------------------ | ------------------------------- | --------------------------------------------------------------------- |
| `/readme-generate`    | Generate OSPO-compliant README | Creating/updating documentation | [`Accelerator README.mdc`](../.cursor/rules/Accelerator%20README.mdc) |
| `/prepare-opensource` | OSPO compliance validation     | Preparing for public release    | [`OSPO-Comppliance.mdc`](../.cursor/rules/OSPO-Comppliance.mdc)       |

---

## 🔄 Skill Workflow Examples

### Example 1: Generating a README

```
User: "generate a readme for this accelerator"

Agent: I'll help you generate an OSPO-compliant README. Let me gather some information:

1. What is your project name? (e.g., "NZC EasyAudit")
> NZC EasyAudit

2. What's your GitHub username or organization?
> salesforce-misc

3. What's the repository name?
> NZC-EasyAudit

4. What's the tagline (1-2 sentence description)?
> A comprehensive audit component that displays step-by-step emissions calculations…

[Continues with interactive questions, then generates complete README]
```

### Example 2: Preparing for Open Source

```
User: "/prepare-opensource"

Agent: I'll validate OSPO compliance and prepare your repository for open source release.

Step 1: Checking required files...
- LICENSE.txt found
- CONTRIBUTING.md missing
- CODE_OF_CONDUCT.md missing
- SECURITY.md found
- README.md found

Step 2: Generating missing files...
What governance model? (1=Community, 2=Salesforce Sponsored, 3=Published)
> 2

[Generates CONTRIBUTING.md and CODE_OF_CONDUCT.md]

Step 3: Scanning for internal references...
Found 2 internal references:
- force-app/main/default/classes/Controller.cls:42 (internal tool reference)

Would you like me to show details? (Y/n)

[Continues through all steps, creates checklist]
```

---

## 💡 Tips for Success

### When to Use Skills

- Multi-step complex tasks
- Tasks requiring validation
- Need interactive guidance
- OSPO compliance workflows
- Documentation generation

### When to Reference Rules Directly

- Quick reference for coding patterns
- Understanding best practices
- Manual implementation
- Learning standards

### Best Practices

1. **Be specific** when invoking skills with details
2. **Answer prompts** completely for best results
3. **Review output** before confirming changes
4. **Combine skills** for comprehensive workflows (e.g., generate README then prepare for open source)

---

## 🛠️ Adding a New Skill

To add another skill to this project, create a folder under `.cursor/skills/` with a `SKILL.md` file inside. The required YAML frontmatter is `name` and `description` (the description is what the agent runtime uses to decide whether to surface the skill on a given prompt — write it as a clear "use when …" sentence).

```markdown
---
name: my-skill
description: Use when the user asks to <trigger>. Performs <one-line summary of the workflow>.
---

# My Skill

Detailed step-by-step instructions for the agent.

## Workflow

1. ...
2. ...
3. ...

## Interactive Prompts

- Ask user about X
- Confirm Y before writing
```

After committing the new skill folder, both Cursor and Claude Code agents in this workspace will pick it up automatically — no per-developer install step.

Reference: [Cursor Skills documentation](https://cursor.com/docs/skills).

---

## 📚 Related Documentation

- [`CLAUDE.md`](../CLAUDE.md) — Complete Claude Code instructions for this repo
- [`.cursor/rules/`](../.cursor/rules/) — All coding standards and rules
- [`AI_ASSISTANT_SETUP.md`](../AI_ASSISTANT_SETUP.md) — AI assistant configuration
- [`README.md`](../README.md) — Project overview

---

## 🤝 Contributing New Skills

Have an idea for a new skill? Consider:

1. Is it a multi-step workflow? (good candidate)
2. Does it require user input/validation? (good candidate)
3. Is it project-specific or general? (project-specific skills go in `.cursor/skills/`)
4. Does it reference existing rules? (ideal)

Submit skill proposals via GitHub Issues or Pull Requests.

---

**Skills available**: 2 (`readme-generate`, `prepare-opensource`)
**Skill location**: `.cursor/skills/` (project-local, ships with the repo)
