# Workspace

Workspace is an Amiasea imperative tool for resolving and building a
multi-repository development workspace.

## Dev Container Feature

Add the Workspace Feature to a Dev Container:

```json
{
  "features": {
    "ghcr.io/amiasea/features/workspace:1": {}
  }
}
```

Once installed, the Workspace commands are available to PowerShell:

```powershell
Resolve-Workspace | Build-Workspace
```

### Commands

* **`Resolve-Workspace`**  
  Resolves Amiasea repository metadata into a workspace topology.

* **`Build-Workspace`**  
  Builds the resolved workspace topology on the local filesystem.
