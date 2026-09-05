function Resolve-Workspace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Organization
    )

    $repositories = @(
        Get-GitHubRepository -OrganizationName $Organization
    )

    $repositoryRecords = @(
        foreach ($repository in $repositories) {
            [WorkspaceRepository]@{
                type       = 'repository'
                repository = "$Organization/$($repository.Name)"
                name       = $repository.Name
                path       = $repository.Name
                clone_url  = $repository.CloneUrl
            }
        }
    )

    $prefixCounts = @{}

    foreach ($repository in $repositoryRecords) {
        $segments = $repository.name -split '-'

        for ($length = 1; $length -lt $segments.Count; $length++) {
            $prefix = $segments[0..($length - 1)] -join '-'

            if ($prefixCounts.ContainsKey($prefix)) {
                $prefixCounts[$prefix]++
            }
            else {
                $prefixCounts[$prefix] = 1
            }
        }
    }

    $normalizedRepositories = @(
        foreach ($repository in $repositoryRecords) {
            $segments = $repository.name -split '-'
            $parent = $null
            $childName = $repository.name

            for ($length = $segments.Count - 1; $length -ge 1; $length--) {
                $candidate = $segments[0..($length - 1)] -join '-'

                if ($prefixCounts[$candidate] -ge 2) {
                    $parent = $candidate
                    $childName = $segments[$length..($segments.Count - 1)] -join '-'
                    break
                }
            }

            [pscustomobject]@{
                repository = $repository.repository
                name       = $childName
                parent     = $parent
                clone_url  = $repository.clone_url
            }
        }
    )

    $rootRepositories = @(
        $normalizedRepositories |
            Where-Object { $null -eq $_.parent }
    )

    $logicalParents = @(
        $normalizedRepositories |
            Where-Object { $null -ne $_.parent } |
            Group-Object -Property parent
    )

    $children = @(
        $rootRepositories | ForEach-Object {
            [WorkspaceRepository]@{
                type       = 'repository'
                repository = $_.repository
                name       = $_.name
                path       = $_.name
                clone_url  = $_.clone_url
            }
        }

        $logicalParents | ForEach-Object {
            $parent = $_.Name

            if ($rootRepositories.name -contains $parent) {
                throw "Repository '$parent' conflicts with logical parent '$parent'."
            }

            [WorkspaceLogicalParent]@{
                type     = 'logical_parent'
                name     = $parent
                path     = $parent
                children = @(
                    $_.Group | ForEach-Object {
                        [WorkspaceRepository]@{
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
    )

    return [Workspace]@{
        root     = '/workspaces'
        children = $children
    }
}