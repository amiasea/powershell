function Build-Workspace {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $Workspace
    )

    process {
        foreach ($node in $Workspace.children) {
            if ($node.type -eq 'repository') {
                $target = Join-Path $Workspace.workspace_root $node.path

                if (Test-Path $target) {
                    if (-not (Test-Path (Join-Path $target '.git'))) {
                        throw "Workspace path already exists and is not a Git repository: $target"
                    }

                    continue
                }

                git clone $node.clone_url $target

                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to clone $($node.repository) to $target"
                }
            }
            elseif ($node.type -eq 'logical_parent') {
                $parentPath = Join-Path $Workspace.workspace_root $node.path

                New-Item -ItemType Directory -Path $parentPath -Force |
                    Out-Null

                foreach ($repository in $node.children) {
                    $target = Join-Path $Workspace.workspace_root $repository.path

                    if (Test-Path $target) {
                        if (-not (Test-Path (Join-Path $target '.git'))) {
                            throw "Workspace path already exists and is not a Git repository: $target"
                        }

                        continue
                    }

                    git clone $repository.clone_url $target

                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to clone $($repository.repository) to $target"
                    }
                }
            }
        }
    }
}