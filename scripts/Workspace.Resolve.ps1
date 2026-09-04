function Resolve-Workspace {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $repositories = @(
        gh repo list amiasea `
            --limit 1000 `
            --source `
            --json name,nameWithOwner,sshUrl,repositoryTopics |
            ConvertFrom-Json
    )

    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to resolve Amiasea repositories.'
    }

    $normalizedRepositories = @(
        foreach ($repository in $repositories) {
            $metadata = @(
                $repository.repositoryTopics |
                    ForEach-Object {
                        if ($_ -match '^([^-]+)-(.+)$') {
                            [pscustomobject]@{
                                label = $Matches[1]
                                value = $Matches[2]
                            }
                        }
                    }
            )

            $workspaces = @(
                $metadata |
                    Where-Object { $_.label -eq 'workspace' } |
                    Select-Object -ExpandProperty value
            )

            if ('amiasea' -notin $workspaces) {
                continue
            }

            $parent = (
                $metadata |
                    Where-Object { $_.label -eq 'parent' } |
                    Select-Object -ExpandProperty value
            )

            $display = (
                $metadata |
                    Where-Object { $_.label -eq 'display' } |
                    Select-Object -ExpandProperty value
            )

            if ([string]::IsNullOrEmpty($display)) {
                $display = $repository.name
            }

            [pscustomobject]@{
                repository = $repository.nameWithOwner
                name       = $display
                parent     = $parent
                clone_url  = $repository.sshUrl
            }
        }
    )

    $children = @(
        $normalizedRepositories |
            Group-Object -Property parent |
            ForEach-Object {
                $parent = $_.Name

                if ([string]::IsNullOrEmpty($parent)) {
                    $_.Group | ForEach-Object {
                        [ordered]@{
                            type       = 'repository'
                            repository = $_.repository
                            name       = $_.name
                            path       = $_.name
                            clone_url  = $_.clone_url
                        }
                    }
                }
                else {
                    [ordered]@{
                        type     = 'logical_parent'
                        name     = $parent
                        path     = $parent
                        children = @(
                            $_.Group | ForEach-Object {
                                [ordered]@{
                                    type       = 'repository'
                                    repository = $_.repository
                                    name       = $_.name
                                    path       = "$parent/$($_.name)"
                                    clone_url  = $_.clone_url
                                }
                            }
                        )
                    }
                }
            }
    )

    [ordered]@{
        workspace_root = '/workspaces'
        children       = $children
    }
}