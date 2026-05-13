# USEEIO Matching Agent

A Salesforce application for matching and working with USEEIO v2.0 (US Environmentally-Extended Input-Output Model) data.

## About USEEIO v2.0 and NAICS Codes

This project works with **NAICS 2017 industry classification codes** for matching and analysis with the USEEIO v2.0 environmental-economic model.

**USEEIO v2.0** is an environmental-economic model of US goods and services that enables comprehensive life cycle assessment, environmental footprinting, and national prioritization. The model includes:

- **NAICS 2017 codes** for industry classification (hierarchical 6-digit structure)
- Environmental impacts, resource use, waste generation, and economic metrics
- Domestic and foreign impact separation capabilities
- Multiple price variants (producer vs. purchaser prices)
- **411 BEA commodity categories** in the underlying model structure (with crosswalks to NAICS)

**Key Principle:** The same USEEIO principles apply whether working with NAICS codes or BEA commodity categories. Environmental data sources use NAICS codes, which are then mapped to BEA commodity categories in the USEEIO model.

For comprehensive details, see:
- [NAICS_KNOWLEDGE_BASE.md](documentation/reference/NAICS_KNOWLEDGE_BASE.md) - NAICS 2017 classification system
- [USEEIO_KNOWLEDGE_BASE.md](documentation/reference/USEEIO_KNOWLEDGE_BASE.md) - USEEIO v2.0 model (based on Ingwersen et al., 2022)

## Development standards

- **[REPOSITORY_SUMMARY.md](./REPOSITORY_SUMMARY.md)** — Architecture, key Apex/LWC components, and documentation index (primary onboarding doc for contributors and AI tools).
- **[SALESFORCE_BEST_PRACTICES.md](documentation/standards/SALESFORCE_BEST_PRACTICES.md)** — Salesforce patterns for this app, including **alignment with the [Salesforce EMU LLM-Based-SalesforceProject](https://github.com/jvillalpando_sfemu/LLM-Based-SalesforceProject) template**: Queueable (not `@future`), optional Finalizer pattern, LWC/testing conventions, and Prompt Builder–first LLM configuration.

## Salesforce DX Project: Next Steps

Now that you've created a Salesforce DX project, what's next? Here are some documentation resources to get you started.

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
