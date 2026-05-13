# Salesforce Connection Issue - Architecture Mismatch

## Problem
You're getting the error: `Bad CPU type in executable` when trying to connect to Salesforce.

**Root Cause:** Your shell is running in Intel (x86_64) mode via Rosetta, but the Salesforce CLI's bundled Node.js is ARM64-only, causing an architecture mismatch.

## Solutions

### Option 1: Reinstall Salesforce CLI (Recommended)

1. **Uninstall the current CLI:**
   ```bash
   sudo rm -rf /usr/local/lib/sf
   sudo rm -f /usr/local/bin/sf
   ```

2. **Reinstall using the official installer:**
   - Visit: https://developer.salesforce.com/tools/salesforcecli
   - Download the macOS installer for your architecture
   - Run the installer

   OR use npm (if you have Node.js installed):
   ```bash
   npm install -g @salesforce/cli
   ```

### Option 2: Quick Workaround (Use System Node)

Temporarily rename the bundled Node so the CLI uses your system Node:

```bash
sudo mv /usr/local/lib/sf/bin/node /usr/local/lib/sf/bin/node.backup
```

Then try connecting again:
```bash
sf org list
sf org login web
```

**Note:** This workaround may break if Salesforce CLI updates, so Option 1 is preferred.

### Option 3: Run Shell in Native ARM64 Mode

If you're on Apple Silicon (M1/M2/M3), ensure your terminal runs in native mode:
- Check Terminal/VS Code settings to disable Rosetta
- Or use a native ARM64 terminal

## Verify the Fix

After applying a solution, test the connection:
```bash
sf --version
sf org list
sf org login web
```

## Additional Resources
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce CLI Installation](https://developer.salesforce.com/tools/salesforcecli)
