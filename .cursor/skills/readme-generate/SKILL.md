---
name: readme-generate
description: Use when the user asks to generate, create, update, fix, or scaffold a README for this Salesforce accelerator, or says any of "generate readme", "create readme", "update readme", "make readme ospo compliant", or "/readme-generate". Produces or updates an OSPO-compliant README that follows the Salesforce accelerator template (badges, three install paths, OSPO disclaimer).
---

# README Generator Skill

Generate or update OSPO-compliant README files for Salesforce accelerators following enterprise standards.

## Metadata

- **Skill Name**: readme-generate
- **Version**: 1.0.0
- **Category**: Documentation
- **Applies To**: Salesforce accelerators, open source projects
- **References**: `.cursor/rules/Accelerator README.mdc`

## Triggers

This skill activates when the user says:

- "generate readme"
- "create readme"
- "update readme"
- "fix readme"
- "/readme-generate"
- "make readme ospo compliant"
- "add readme documentation"

## Capabilities

- Generate complete OSPO-compliant README from scratch
- Update specific sections of existing README
- Validate required sections and structure
- Ensure three installation paths (GitHub Deploy, Workbench, CLI)
- Format badges, mermaid diagrams, and tables properly
- Add OSPO-compliant disclaimer and license references

## Workflow

### Step 1: Assess Current State

1. Check if README.md exists in repository root
2. If exists: Read current content and identify what needs updating
3. If missing: Prepare to generate from scratch

### Step 2: Gather Project Information

Ask the user for the following (skip if updating existing sections):

**Required Information**:

- Project name (e.g., "NZC EasyAudit")
- GitHub username or organization (e.g., "salesforce-misc")
- Repository name (e.g., "NZC-EasyAudit")
- Tagline/description (1-2 sentences)
- Primary Salesforce product (Net Zero Cloud, Sales Cloud, etc.)

**Optional Information** (can infer from codebase):

- Key features (3-5 categories with bullet points)
- Technical components (LWC, Apex classes, Flows)
- Prerequisites
- Post-deployment steps

### Step 3: Generate or Update Content

Based on user response, either:

- **Generate full README**: Create complete structure following template
- **Update sections**: Modify specific sections as requested

### Step 4: Validate OSPO Compliance

Ensure the following are present:

- Three installation paths (One-Click GitHub Deploy, Workbench, CLI)
- OSPO-compliant disclaimer
- License reference section
- Bug reporting section with GitHub Issues link
- Contributing section
- Support section with multiple channels

### Step 5: Preview and Confirm

1. Show generated/updated content to user
2. Explain what was added/changed
3. Ask if any sections need modification
4. Write final content to README.md

## Required Sections (in order)

### 1. Title with Emoji

```markdown
# {{EMOJI}} {{PROJECT_NAME}}
```

Use relevant emoji: 📊, 🚀, ⚡, 🔧, 📋, etc.

### 2. Tagline (Blockquote)

```markdown
> **{{TAGLINE_DESCRIPTION}}**
```

### 3. Badges Section

```markdown
[![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)](https://salesforce.com)
[![{{PRODUCT}}](https://img.shields.io/badge/{{PRODUCT}}-{{COLOR}}?style=for-the-badge&logo=salesforce&logoColor=white)]({{PRODUCT_URL}})
```

Colors: `00A1E0` (Salesforce), `FFB000` (Net Zero Cloud), `1798C1` (Lightning)

### 4. Quick Deploy Section (Centered)

```markdown
## 🚀 Quick Deploy

<div align="center">

[![Deploy to Salesforce](https://img.shields.io/badge/Deploy%20to%20Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)](https://githubsfdeploy.herokuapp.com?owner={{USER}}&repo={{REPO}}&ref=main)

**One-click deployment to your Salesforce org**

> **Note:** You'll need to authenticate with your Salesforce org. Alternatively, use the [Salesforce CLI deployment method](#-option-3-salesforce-cli-deployment) below.

</div>

---
```

### 5. Features Section

```markdown
## ✨ Features

### {{EMOJI}} **{{CATEGORY_NAME}}**

- **{{Feature}}**: {{Description}}
- **{{Feature}}**: {{Description}}

[Repeat for 2-4 categories]

---
```

### 6. Getting Started Section

Must include:

- Prerequisites checklist (with ✅)
- Three installation options (numbered):
  1. One-Click GitHub Deploy (Recommended)
  2. Workbench Deployment
  3. Salesforce CLI Deployment
- Post-Deployment Configuration steps (numbered)

### 7. Usage Section

```markdown
## 🎯 Usage

### {{EMOJI}} **{{Scenario}}**

1. **{{Action}}** {{Description}}
2. **{{Action}}** {{Description}}
   [...]
```

### 8. Technical Architecture Section

Must include:

- Metadata list (components count)
- Optional: Mermaid diagram
- Key Components table

### 9. Contributing Section

```markdown
## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### 📝 **Development Guidelines**

- Follow [Salesforce coding standards](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_best_practices.htm)
- Include comprehensive test coverage (>75%)
- Update documentation for new features
- Test thoroughly in multiple org types
```

### 10. License Section

```markdown
## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE.md](LICENSE.md) file for details.

---
```

### 11. Bug Reporting Section

```markdown
## 🐛 How to Report Bugs

Found a bug or have a feature request? Please report it via [GitHub Issues](https://github.com/{{USER}}/{{REPO}}/issues).

When reporting bugs, please include:

- Steps to reproduce the issue
- Expected vs. actual behavior
- Salesforce org version and edition
- Screenshots or error messages (if applicable)
```

### 12. Support Section

```markdown
## 🆘 Support

- 📚 **Documentation**: Check our [Wiki](https://github.com/{{USER}}/{{REPO}}/wiki) for detailed guides
- 🐛 **Issues**: Report bugs via [GitHub Issues](https://github.com/{{USER}}/{{REPO}}/issues)
- 💬 **Discussions**: Join the conversation in [GitHub Discussions](https://github.com/{{USER}}/{{REPO}}/discussions)
- 📧 **Contact**: Reach out to the maintainers for enterprise support
```

### 13. OSPO Disclaimer (MANDATORY)

```markdown
## ⚠️ Disclaimer

**This accelerator is open-source, not an official Salesforce product, and is community-supported.** Salesforce does not provide official support for this accelerator. Use at your own risk and test thoroughly in a sandbox environment before deploying to production.

---
```

### 14. Footer (Optional)

```markdown
<div align="center">

**Made with ❤️ for the Salesforce Community**

⭐ **Star this repo** if you find it helpful!

</div>
```

## Validation Checklist

Before finalizing, verify:

- [ ] All three installation paths included
- [ ] OSPO disclaimer present and bold
- [ ] License section references LICENSE.md
- [ ] GitHub Issues link works
- [ ] Deploy button URL has correct owner/repo
- [ ] All placeholders replaced
- [ ] Badges properly formatted
- [ ] Horizontal rules (---) between major sections
- [ ] Code blocks have language tags
- [ ] Mermaid diagrams are valid (if included)
- [ ] Tables properly formatted

## Example Output Structure

```markdown
# 📊 Project Name

> **Tagline**

[Badges]

## 🚀 Quick Deploy

[Deploy button]

---

## ✨ Features

[Feature categories]

---

## 🚀 Getting Started

### 📋 Prerequisites

### 🔧 Installation

#### 🎯 Option 1: One-Click GitHub Deploy

#### 📦 Option 2: Workbench Deployment

#### 🛠️ Option 3: Salesforce CLI Deployment

#### ⚡ Post-Deployment Configuration

---

## 🎯 Usage

[Usage scenarios]

---

## 🏗️ Technical Architecture

[Metadata and diagrams]

---

## 🤝 Contributing

[Contribution workflow]

---

## 📄 License

[License reference]

---

## 🐛 How to Report Bugs

[Bug reporting]

## 🆘 Support

[Support channels]

## ⚠️ Disclaimer

[OSPO disclaimer]

---

[Optional footer]
```

## Tips for Success

1. **Infer from codebase**: Look at `sfdx-project.json`, `package.json`, and file structure to determine components
2. **Check existing README**: If updating, preserve custom sections not in template
3. **Use REPOSITORY_SUMMARY.md**: Reference for technical details if it exists
4. **Badge colors**: Salesforce=00A1E0, NZC=FFB000, Lightning=1798C1
5. **Emoji consistency**: Use relevant emojis but don't overdo it
6. **Links validation**: Ensure all internal links work (e.g., `#-option-3-salesforce-cli-deployment`)

## Error Handling

If user provides insufficient information:

- Ask specific follow-up questions
- Offer to infer from codebase
- Provide reasonable defaults with confirmation

If README exists and user wants to update:

- Ask which specific section(s) to update
- Preserve existing content unless explicitly replacing
- Maintain consistent formatting with existing style

## Post-Generation Actions

After generating/updating README:

1. Confirm with user that content looks correct
2. Remind to update LICENSE.md if referenced
3. Suggest running `/prepare-opensource` if preparing for public release
4. Offer to create additional documentation if needed

---

**Related Skills**: `/prepare-opensource` (OSPO compliance)  
**Related Rules**: `Accelerator README.mdc`, `OSPO-Comppliance.mdc`
