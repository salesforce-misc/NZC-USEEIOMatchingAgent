---
name: prepare-opensource
description: Use when the user asks to prepare this Salesforce accelerator for public open source release, validate OSPO compliance, generate compliance files (LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY), scan for internal Salesforce references, add copyright headers, or says any of "prepare for open source", "ospo check", "ready for github", "validate compliance", or "/prepare-opensource".
---

# Open Source Preparation Skill

Validate OSPO compliance and prepare Salesforce accelerator repositories for public open source release.

## Metadata

- **Skill Name**: prepare-opensource
- **Version**: 1.0.0
- **Category**: Compliance & Legal
- **Applies To**: Salesforce accelerators preparing for open source release
- **References**: `.cursor/rules/OSPO-Comppliance.mdc`

## Triggers

This skill activates when the user says:

- "prepare for open source"
- "check ospo compliance"
- "make repo public"
- "/prepare-opensource"
- "ospo check"
- "validate compliance"
- "prepare for publication"
- "ready for github"

## Capabilities

- Validate OSPO compliance requirements
- Generate missing compliance files (LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY)
- Scan for internal Salesforce references
- Add copyright headers to source files
- Verify file locations (must be at root level)
- Create compliance checklist
- Guide through approval process

## Workflow

### Step 1: Introduction & Context

Explain to the user:

```
I'll help prepare your repository for open source release by:
1. Checking required compliance files
2. Validating file locations and content
3. Scanning for internal references
4. Adding copyright headers
5. Creating a compliance checklist

This follows Salesforce OSPO requirements based on:
https://github.com/salesforce/oss-template
```

### Step 2: Check Required Files

Verify the following files exist at **root level only** (not in subdirectories):

- [ ] LICENSE.txt (or LICENSE)
- [ ] CONTRIBUTING.md
- [ ] CODE_OF_CONDUCT.md
- [ ] SECURITY.md
- [ ] README.md
- [ ] CODEOWNERS (optional but recommended)

**CRITICAL**: Files MUST be at root level. Files in subdirectories (e.g., `docs/LICENSE.md`) do NOT satisfy requirements.

### Step 3: For Each Missing File, Generate It

#### LICENSE.txt

If missing, ask user:

- "What year should I use for the copyright? (default: current year)"

Then create LICENSE.txt with full Apache License 2.0 text:

```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   [Full Apache 2.0 license text]

   Copyright (c) [YEAR], Salesforce, Inc.
   All rights reserved.

   SPDX-License-Identifier: Apache-2.0
```

**Template Source**: https://raw.githubusercontent.com/salesforce/oss-template/main/LICENSE.txt

#### CONTRIBUTING.md

If missing, ask user:

- "What governance model? Options: 1) Community Based, 2) Salesforce Sponsored, 3) Published (not supported)"
- "What is your repository name?"

Then create CONTRIBUTING.md with sections:

- Governance Model
- Getting Started
- Issues, Requests & Ideas
- Contribution Checklist
- Creating a Pull Request
- CLA Reference (https://cla.salesforce.com/sign-cla)
- Code of Conduct Reference
- License Reference

**Template Source**: https://raw.githubusercontent.com/salesforce/oss-template/main/CONTRIBUTING.md

#### CODE_OF_CONDUCT.md

If missing, create with **exact content** from Salesforce OSS template.

**Must include**:

- Salesforce Open Source Community Code of Conduct
- Contact email: `ossconduct@salesforce.com`

**Template Source**: https://raw.githubusercontent.com/salesforce/oss-template/main/CODE_OF_CONDUCT.md

#### SECURITY.md

If missing, create with security policy.

**Must include**:

- Security reporting email: `security@salesforce.com`
- Reporting instructions
- Expected response time

**Template Source**: https://raw.githubusercontent.com/salesforce/oss-template/main/SECURITY.md

#### CODEOWNERS (Optional)

If requested, create with repository maintainer GitHub handles.

Format:

```
* @owner1 @owner2
/force-app/ @lwc-owner
/docs/ @doc-owner
```

### Step 4: Validate Existing Files

For files that already exist, verify:

**LICENSE.txt**:

- [ ] Contains full Apache 2.0 license text
- [ ] Copyright year is appropriate
- [ ] No placeholder text remaining

**CONTRIBUTING.md**:

- [ ] Governance model selected
- [ ] All placeholders replaced (e.g., `{project_slug}`)
- [ ] CLA reference: https://cla.salesforce.com/sign-cla
- [ ] Code of Conduct reference present
- [ ] License reference present

**CODE_OF_CONDUCT.md**:

- [ ] Matches Salesforce template exactly
- [ ] Contact email `ossconduct@salesforce.com` present
- [ ] No modifications to standard text

**SECURITY.md**:

- [ ] Security email `security@salesforce.com` present
- [ ] Appropriate security policy content

**README.md**:

- [ ] Contains detailed, useful project information
- [ ] Not just placeholder text
- [ ] Includes OSPO-compliant disclaimer
- [ ] References LICENSE.md

### Step 5: Scan for Internal References

Search all files for internal Salesforce references that must be scrubbed:

**Internal Domains**:

- `*.sfdc.sh`
- `*.salesforce.com` (internal wiki links)
- `git.soma.salesforce.com`
- Internal Git hosts

**Internal Tools**:

- GUS (reference to internal issue tracking)
- Grand Slam
- Internal Jenkins/CI systems
- Bazel commands (internal build tool)

**Internal Comments**:

- "TO DO (Internal)"
- Employee names
- Internal team codes

**Non-Public Dependencies**:

- Check `sfdx-project.json` for private dependencies
- Check `package.json` for internal npm packages

**Action**: Report all findings to user and suggest replacements:

- Internal links → Public documentation links
- Internal tools → Generic descriptions
- Employee names → Remove or genericize

### Step 6: Add Copyright Headers

For all source files **without** copyright headers, add the Salesforce standard header.

**File types requiring headers**:

- `.cls` (Apex classes)
- `.trigger` (Apex triggers)
- `.js` (JavaScript/LWC)
- `.css` (Stylesheets)
- `.html` (HTML templates)
- `.cmp` (Aura components)
- `.js-meta.xml` (Metadata - optional but recommended)

**Apex/JS/CSS Header**:

```apex
/*
 * Copyright (c) [YEAR], Salesforce, Inc.
 * All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
 */
```

**HTML/CMP Header**:

```html
<!--
 Copyright (c) [YEAR], Salesforce, Inc.
 All rights reserved.
 SPDX-License-Identifier: Apache-2.0
 For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/Apache-2.0
-->
```

**Process**:

1. Scan for files without headers
2. Show user count and file list
3. Ask for copyright year (default: current year)
4. Add headers to all applicable files

### Step 7: Create Compliance Checklist

Generate a final checklist and present to user:

```markdown
## OSPO Compliance Checklist

### Required Files (Root Level)

- [x] LICENSE.txt - Apache 2.0 license with current year
- [x] CONTRIBUTING.md - Governance model, CLA, Code of Conduct references
- [x] CODE_OF_CONDUCT.md - Salesforce template with ossconduct@salesforce.com
- [x] SECURITY.md - Security reporting to security@salesforce.com
- [x] README.md - Detailed project info with OSPO disclaimer
- [ ] CODEOWNERS - (Optional) Maintainer assignments

### Content Validation

- [x] All placeholders replaced
- [x] No internal references found
- [x] Copyright headers added to [X] files
- [x] All dependencies are public

### File Location Verification

- [x] All required files at root level (not in subdirectories)
- [x] File names match exactly (case-sensitive)

### Internal Reference Scan

- [ ] No \*.sfdc.sh domains
- [ ] No internal Salesforce.com links
- [ ] No internal tool references
- [ ] No employee names or internal comments

### Next Steps

- [ ] Review all changes
- [ ] Test in sandbox environment
- [ ] Obtain VP Approval
- [ ] Obtain Legal Approval
- [ ] Obtain OSPO Approval via https://oss-request2.sfdc.sh/
```

### Step 8: Final Approval Reminder

**MANDATORY**: Show this message to the user:

```
⚠️ IMPORTANT: Before Making Repository Public

This repository now meets OSPO technical requirements. However, you MUST obtain
the following approvals before making it public:

1. VP Approval
2. Legal Approval
3. OSPO Approval

Submit your request at: https://oss-request2.sfdc.sh/

Do NOT make this repository public without proper approvals.
```

## Validation Commands

### Verify Files at Root Level

```bash
ls -la | grep -E "(LICENSE|CONTRIBUTING|CODE_OF_CONDUCT|SECURITY|README|CODEOWNERS)"
```

### Scan for Internal References

```bash
# Scan for internal domains
rg "\.sfdc\.sh" --glob '!node_modules' --glob '!.git'
rg "git\.soma\.salesforce\.com" --glob '!node_modules' --glob '!.git'

# Scan for internal tools
rg "GUS|Grand Slam" --glob '!node_modules' --glob '!.git'

# Check dependencies
cat sfdx-project.json | grep -i "internal\|private"
cat package.json | grep -i "@salesforce-internal"
```

### Find Files Needing Copyright Headers

```bash
# Find Apex files without copyright
find force-app -name "*.cls" -o -name "*.trigger" | xargs grep -L "Copyright (c)"

# Find JS/LWC files without copyright
find force-app -name "*.js" | xargs grep -L "Copyright (c)"

# Find HTML files without copyright
find force-app -name "*.html" -o -name "*.cmp" | xargs grep -L "Copyright (c)"
```

## Error Handling

### If Files Are in Wrong Location

```
ERROR: Required files must be at repository root level.

Found: ./docs/LICENSE.md
Required: ./LICENSE.txt

Action: Move files to root directory with correct names.
```

### If Internal References Found

```
WARNING: Internal references detected:

File: force-app/main/default/classes/Controller.cls
Line 42: // TODO: Ask John Smith about this (internal)

Action: Remove or replace with generic text.
```

### If Copyright Headers Missing

```
INFO: Found 23 files without copyright headers:
- force-app/main/default/classes/AccountSelector.cls
- force-app/main/default/lwc/myComponent/myComponent.js
[... 21 more files]

Would you like me to add headers to all files? (Y/n)
```

## Interactive Prompts

Throughout the process, ask:

1. "What copyright year? (default: {current_year})"
2. "What governance model? (1=Community, 2=Salesforce Sponsored, 3=Published)"
3. "Found {X} internal references. Review details? (Y/n)"
4. "Add copyright headers to {X} files? (Y/n)"
5. "Create CODEOWNERS file? (y/N)"
6. "Generate compliance report? (Y/n)"

## Success Criteria

Repository is ready for OSPO submission when:

- All required files exist at root level
- All file content matches templates
- No internal references found
- All source files have copyright headers
- Dependencies are all public
- README includes OSPO disclaimer
- Compliance checklist complete

## Related Actions

After completion:

1. Suggest running `/readme-generate` if README needs OSPO updates
2. Remind about approval process
3. Suggest testing in sandbox
4. Offer to generate compliance report

## Templates Reference

All templates based on: https://github.com/salesforce/oss-template

### Key URLs

- **OSS Template**: https://github.com/salesforce/oss-template
- **OSS Request Portal**: https://oss-request2.sfdc.sh/
- **Apache 2.0 License**: https://www.apache.org/licenses/LICENSE-2.0
- **Salesforce CLA**: https://cla.salesforce.com/sign-cla
- **Security Contact**: security@salesforce.com
- **Code of Conduct Contact**: ossconduct@salesforce.com

## Tips for Success

1. **Always check file locations first** - Most common issue is files in wrong directory
2. **Use exact template content** for CODE_OF_CONDUCT.md - Do not modify
3. **Scan thoroughly** for internal references - Automated tools might miss some
4. **Batch copyright headers** - More efficient than file-by-file
5. **Generate report** - Useful for approval submissions

## Post-Completion Report

After all steps complete, generate summary:

```markdown
## Open Source Preparation Complete

### Files Created/Updated

- LICENSE.txt (Apache 2.0, Copyright {year})
- CONTRIBUTING.md (Governance: {model})
- CODE_OF_CONDUCT.md (Salesforce template)
- SECURITY.md (Contact: security@salesforce.com)

### Actions Taken

- Added copyright headers to {X} files
- Removed {Y} internal references
- Validated all file locations

### Remaining Actions

1. Review all changes in detail
2. Test in sandbox environment
3. Submit OSPO approval request: https://oss-request2.sfdc.sh/
4. Obtain VP and Legal approvals

Do NOT make repository public until all approvals received
```

---

**Related Skills**: `/readme-generate` (README documentation)  
**Related Rules**: `OSPO-Comppliance.mdc`, `Accelerator README.mdc`  
**Critical**: Files MUST be at root level. This is non-negotiable.
