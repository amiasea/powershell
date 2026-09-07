using module ../../../src/workspace/Workspace.Types.psm1
using module ../../../src/workspace/Workspace.psm1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/workspace/Workspace.psm1'

    Import-Module $modulePath -Force
}

Describe 'Build-Workspace' {
    BeforeEach {
        $workspace = [Workspace]::new()
        $workspace.root = Join-Path $TestDrive 'workspaces'

        $api = [WorkspaceRepository]::new()
        $api.repository = 'example/api'
        $api.name = 'api'
        $api.path = 'api'
        $api.clone_url = 'https://github.com/example/api.git'

        $web = [WorkspaceRepository]::new()
        $web.repository = 'example/web'
        $web.name = 'web'
        $web.path = 'web'
        $web.clone_url = 'https://github.com/example/web.git'

        $workspace.children = [WorkspaceChild[]]@(
            $api
            $web
        )

        Mock `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -MockWith {}
    }

    It 'clones each repository when the target path does not exist' {
        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $false
            }

        Build-Workspace -Workspace $workspace

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 2 `
            -Exactly
    }

    It 'clones each repository using its clone URL and target path' {
        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $false
            }

        Build-Workspace -Workspace $workspace

        $apiPath = Join-Path $workspace.root $api.path
        $webPath = Join-Path $workspace.root $web.path

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Url -eq $api.clone_url -and
                $Path -eq $apiPath
            }

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Url -eq $web.clone_url -and
                $Path -eq $webPath
            }
    }

    It 'does not clone an existing Git repository' {
        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $true
            }

        Build-Workspace -Workspace $workspace

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 0 `
            -Exactly
    }

    It 'throws when an existing repository path is not a Git repository' {
        $apiPath = Join-Path $workspace.root $api.path
        $gitPath = Join-Path $apiPath '.git'

        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                param(
                    $LiteralPath,
                    $PathType
                )

                if ($LiteralPath -eq $apiPath) {
                    return $true
                }

                if ($LiteralPath -eq $gitPath -and $PathType -eq 'Container') {
                    return $false
                }

                return $false
            }

        {
            Build-Workspace -Workspace $workspace
        } | Should -Throw "Workspace path already exists and is not a Git repository: $apiPath"
    }

    It 'creates a missing logical parent directory' {
        $logicalParent = [WorkspaceLogicalParent]::new()
        $logicalParent.name = 'platform'
        $logicalParent.path = 'platform'

        $platformApi = [WorkspaceRepository]::new()
        $platformApi.repository = 'example/platform-api'
        $platformApi.name = 'api'
        $platformApi.path = Join-Path $logicalParent.path 'api'
        $platformApi.clone_url = 'https://github.com/example/platform-api.git'

        $platformWeb = [WorkspaceRepository]::new()
        $platformWeb.repository = 'example/platform-web'
        $platformWeb.name = 'web'
        $platformWeb.path = Join-Path $logicalParent.path 'web'
        $platformWeb.clone_url = 'https://github.com/example/platform-web.git'

        $logicalParent.children = [WorkspaceRepository[]]@(
            $platformApi
            $platformWeb
        )

        $workspace.children = [WorkspaceChild[]]@(
            $logicalParent
        )

        $parentPath = Join-Path $workspace.root $logicalParent.path

        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $false
            }

        Mock `
            -CommandName New-Item `
            -ModuleName Workspace `
            -MockWith {}

        Build-Workspace -Workspace $workspace

        Should -Invoke `
            -CommandName New-Item `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $ItemType -eq 'Directory' -and
                @($Path)[0] -eq $parentPath -and
                $Force
            }
    }

    It 'clones repositories beneath a logical parent' {
        $logicalParent = [WorkspaceLogicalParent]::new()
        $logicalParent.name = 'platform'
        $logicalParent.path = 'platform'

        $platformApi = [WorkspaceRepository]::new()
        $platformApi.repository = 'example/platform-api'
        $platformApi.name = 'api'
        $platformApi.path = Join-Path $logicalParent.path 'api'
        $platformApi.clone_url = 'https://github.com/example/platform-api.git'

        $platformWeb = [WorkspaceRepository]::new()
        $platformWeb.repository = 'example/platform-web'
        $platformWeb.name = 'web'
        $platformWeb.path = Join-Path $logicalParent.path 'web'
        $platformWeb.clone_url = 'https://github.com/example/platform-web.git'

        $logicalParent.children = [WorkspaceRepository[]]@(
            $platformApi
            $platformWeb
        )

        $workspace.children = [WorkspaceChild[]]@(
            $logicalParent
        )

        $parentPath = Join-Path $workspace.root $logicalParent.path
        $apiPath = Join-Path $workspace.root $platformApi.path
        $webPath = Join-Path $workspace.root $platformWeb.path

        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $false
            }

        Mock `
            -CommandName New-Item `
            -ModuleName Workspace `
            -MockWith {}

        Build-Workspace -Workspace $workspace

        Should -Invoke `
            -CommandName New-Item `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $ItemType -eq 'Directory' -and
                @($Path)[0] -eq $parentPath -and
                $Force
            }

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 2 `
            -Exactly

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Url -eq $platformApi.clone_url -and
                $Path -eq $apiPath
            }

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Url -eq $platformWeb.clone_url -and
                $Path -eq $webPath
            }
    }

    It 'does not create an existing logical parent directory' {
        $logicalParent = [WorkspaceLogicalParent]::new()
        $logicalParent.name = 'platform'
        $logicalParent.path = 'platform'

        $workspace.children = [WorkspaceChild[]]@(
            $logicalParent
        )

        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $true
            }

        Mock `
            -CommandName New-Item `
            -ModuleName Workspace `
            -MockWith {}

        Build-Workspace -Workspace $workspace

        Should -Invoke `
            -CommandName New-Item `
            -ModuleName Workspace `
            -Times 0 `
            -Exactly
    }

    It 'does not clone an existing repository beneath a logical parent' {
        $logicalParent = [WorkspaceLogicalParent]::new()
        $logicalParent.name = 'platform'
        $logicalParent.path = 'platform'

        $platformApi = [WorkspaceRepository]::new()
        $platformApi.repository = 'example/platform-api'
        $platformApi.name = 'api'
        $platformApi.path = Join-Path $logicalParent.path 'api'
        $platformApi.clone_url = 'https://github.com/example/platform-api.git'

        $logicalParent.children = [WorkspaceRepository[]]@(
            $platformApi
        )

        $workspace.children = [WorkspaceChild[]]@(
            $logicalParent
        )

        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $true
            }

        Build-Workspace -Workspace $workspace

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 0 `
            -Exactly
    }

    It 'throws when an existing logical parent path is not a directory' {
        $logicalParent = [WorkspaceLogicalParent]::new()
        $logicalParent.name = 'platform'
        $logicalParent.path = 'platform'

        $workspace.children = [WorkspaceChild[]]@(
            $logicalParent
        )

        $parentPath = Join-Path $workspace.root $logicalParent.path

        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                param(
                    $LiteralPath,
                    $PathType
                )

                if ($LiteralPath -eq $parentPath) {
                    if ($PathType -eq 'Container') {
                        return $false
                    }

                    return $true
                }

                return $false
            }

        {
            Build-Workspace -Workspace $workspace
        } | Should -Throw "Workspace path already exists and is not a directory: $parentPath"
    }

    It 'throws for an unknown workspace node type' {
        $unknownNode = [WorkspaceChild]::new()

        Add-Member `
            -InputObject $unknownNode `
            -MemberType NoteProperty `
            -Name type `
            -Value 'unknown'

        $workspace.children = [WorkspaceChild[]]@(
            $unknownNode
        )

        {
            Build-Workspace -Workspace $workspace
        } | Should -Throw "Unknown workspace node type 'unknown'."
    }

    It 'accepts the Workspace from the pipeline' {
        Mock `
            -CommandName Test-Path `
            -ModuleName Workspace `
            -MockWith {
                $false
            }

        $workspace | Build-Workspace

        Should -Invoke `
            -CommandName Invoke-WorkspaceGitClone `
            -ModuleName Workspace `
            -Times 2 `
            -Exactly
    }
}