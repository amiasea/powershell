function Build-Workspace {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Workspace]$Workspace
    )

    process {
        foreach ($node in $Workspace.children) {
            switch ($node.type) {
                'repository' {
                    $target = Join-Path $Workspace.root $node.path

                    if (Test-Path -LiteralPath $target) {
                        if (-not (Test-Path -LiteralPath (Join-Path $target '.git') -PathType Container)) {
                            throw "Workspace path already exists and is not a Git repository: $target"
                        }

                        continue
                    }

                    Invoke-WorkspaceGitClone `
                        -Url $node.clone_url `
                        -Path $target
                }

                'logical_parent' {
                    $parentPath = Join-Path $Workspace.root $node.path

                    if (Test-Path -LiteralPath $parentPath) {
                        if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
                            throw "Workspace path already exists and is not a directory: $parentPath"
                        }
                    }
                    else {
                        New-Item -ItemType Directory -Path $parentPath -Force |
                            Out-Null
                    }

                    foreach ($repository in $node.children) {
                        $target = Join-Path $Workspace.root $repository.path

                        if (Test-Path -LiteralPath $target) {
                            if (-not (Test-Path -LiteralPath (Join-Path $target '.git') -PathType Container)) {
                                throw "Workspace path already exists and is not a Git repository: $target"
                            }

                            continue
                        }

                        Invoke-WorkspaceGitClone `
                            -Url $repository.clone_url `
                            -Path $target
                    }
                }

                default {
                    throw "Unknown workspace node type '$($node.type)'."
                }
            }
        }
    }
}