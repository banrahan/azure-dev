# Using Local Agent Samples

This guide explains how to use a local template catalog with `azd ai agent init`
instead of the default remote catalog.

## Overview

By default, `azd ai agent init` fetches agent templates from the remote
[awesome-azd](https://aka.ms/foundry-agents-samples) catalog. For offline
testing or working with custom samples, you can point the command at a local
JSON file containing the same template entries.

## Setup

### 1. Create a local templates catalog

Create a JSON file (e.g., `templates.json`) containing an array of template
entries. Use the same schema as the remote catalog:

```json
[
  {
    "title": "Echo Agent (Python)",
    "description": "A simple echo agent that repeats user messages",
    "languages": ["python"],
    "extensionFramework": "Agent Framework",
    "source": "samples/echo-agent/agent.yaml",
    "templateType": "extension.ai.agent"
  },
  {
    "title": "Calculator Agent (C#)",
    "description": "An agent with tool-calling capabilities",
    "languages": ["dotnetCsharp"],
    "extensionFramework": "Semantic Kernel",
    "source": "samples/calculator-agent/agent.yaml",
    "templateType": "extension.ai.agent"
  }
]
```

**Important fields:**

| Field                | Description                                                             |
|----------------------|-------------------------------------------------------------------------|
| `title`              | Display name shown in the template picker                               |
| `description`        | Short description (not currently shown in picker, but part of schema)   |
| `languages`          | Array of language tokens: `"python"`, `"dotnetCsharp"`                  |
| `extensionFramework` | Framework label shown in the picker (e.g., `"Agent Framework"`)         |
| `source`             | Path to the `agent.yaml` manifest file (relative or absolute)           |
| `templateType`       | **Must** be `"extension.ai.agent"` — entries with other values are filtered out |

### 2. Create your sample agent manifests

Each `source` path should point to a valid `agent.yaml` file:

```
my-samples/
├── templates.json
└── samples/
    ├── echo-agent/
    │   └── agent.yaml
    └── calculator-agent/
        └── agent.yaml
```

### 3. Set the environment variable

```bash
export AZD_AGENT_TEMPLATES_PATH=/path/to/my-samples/templates.json
```

### 4. Run init

```bash
azd ai agent init
```

The template picker will show your local templates instead of the remote catalog.

## Path Resolution

- **Relative paths** in `source` are resolved relative to the JSON catalog
  file's directory (not the current working directory).
- **Absolute paths** are used as-is.
- **URLs** (`http://` or `https://`) are left unchanged and fetched remotely
  as usual (useful for mixing local and remote templates).

## Template Types

Only **agent manifest** templates (`source` pointing to an `agent.yaml` file)
work with local paths. Full **azd templates** (`TemplateTypeAzd`) require a
GitHub repository slug and cannot be used locally.

The template type is determined by the `source` field:
- Ends with `/agent.yaml` or `/agent.manifest.yaml` → agent manifest (works locally)
- Anything else → full azd template (requires remote repo)

## Unsetting

To revert to the remote catalog, unset the environment variable:

```bash
unset AZD_AGENT_TEMPLATES_PATH
```
