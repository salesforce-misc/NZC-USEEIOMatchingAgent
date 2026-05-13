# GitHub Repository Setup Guide

## Option 1: Using GitHub CLI (Recommended - Fastest)

### Step 1: Install GitHub CLI (if not already installed)

**macOS:**
```bash
brew install gh
```

**Or download from:** https://cli.github.com/

### Step 2: Authenticate with GitHub
```bash
gh auth login
```
Follow the prompts to authenticate.

### Step 3: Create Repository and Push
```bash
cd "/Users/n.hughes/Cursor Projects/USEEIOMatchingAgent"
gh repo create USEEIOMatchingAgent --private --source=. --remote=origin --push
```

**Options:**
- `--private` - Creates a private repository (use `--public` for public)
- `--source=.` - Uses current directory as source
- `--remote=origin` - Sets remote name to origin
- `--push` - Pushes code immediately

## Option 2: Manual Setup (Using GitHub Website)

### Step 1: Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `USEEIOMatchingAgent`
3. Description: "AI-powered matching agent for USEEIO emissions factors in Salesforce Net Zero Cloud"
4. Choose **Private** or **Public**
5. **DO NOT** initialize with README, .gitignore, or license (we already have these)
6. Click **Create repository**

### Step 2: Add Remote and Push

After creating the repository, GitHub will show you commands. Use these:

```bash
cd "/Users/n.hughes/Cursor Projects/USEEIOMatchingAgent"

# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/USEEIOMatchingAgent.git

# Or if using SSH (if you have SSH keys set up):
# git remote add origin git@github.com:YOUR_USERNAME/USEEIOMatchingAgent.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Option 3: Using SSH (If You Have SSH Keys Set Up)

If you prefer SSH and have your SSH keys configured:

```bash
cd "/Users/n.hughes/Cursor Projects/USEEIOMatchingAgent"

# Create repo on GitHub first (via website), then:
git remote add origin git@github.com:YOUR_USERNAME/USEEIOMatchingAgent.git
git branch -M main
git push -u origin main
```

## Verify Setup

After pushing, verify the remote is configured:

```bash
git remote -v
```

You should see:
```
origin  https://github.com/YOUR_USERNAME/USEEIOMatchingAgent.git (fetch)
origin  https://github.com/YOUR_USERNAME/USEEIOMatchingAgent.git (push)
```

## Future Workflow

Once set up, your workflow will be:

```bash
# Make changes
git add .
git commit -m "Description of changes"

# Push to GitHub
git push origin main

# Create feature branches
git checkout -b feature/component-name
# ... make changes ...
git commit -m "Add component"
git push origin feature/component-name
```

## Repository Settings Recommendations

After creating the repository, consider:

1. **Add repository description** on GitHub
2. **Add topics/tags:** salesforce, net-zero-cloud, useeio, naics, llm, agentforce
3. **Set default branch protection** (if working in a team)
4. **Add collaborators** (if needed)
5. **Enable Issues** for tracking bugs/features
6. **Add README badges** (optional)

---

*Choose the option that works best for you. Option 1 (GitHub CLI) is fastest if you have it installed.*
