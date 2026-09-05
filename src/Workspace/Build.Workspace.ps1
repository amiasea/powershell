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

                    git clone $node.clone_url $target

                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to clone $($node.repository) to $target"
                    }
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

                        git clone $repository.clone_url $target

                        if ($LASTEXITCODE -ne 0) {
                            throw "Failed to clone $($repository.repository) to $target"
                        }
                    }
                }

                default {
                    throw "Unknown workspace node type '$($node.type)'."
                }
            }
        }
    }
}