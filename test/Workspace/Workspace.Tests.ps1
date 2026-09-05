BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/Workspace/Workspace.psd1'

    Import-Module $modulePath -Force
}

Describe 'Workspace' {
    BeforeEach {
        $workspaceRoot = Join-Path $TestDrive 'workspaces'

        $repositories = @(
            [WorkspaceRepository]@{
                repository = 'example/api'
                name       = 'api'
                clone_url  = 'https://github.com/example/api.git'
            }

            [WorkspaceRepository]@{
                repository = 'example/web'
                name       = 'web'
                clone_url  = 'https://github.com/example/web.git'
            }

            [WorkspaceRepository]@{
                repository = 'example/platform-api'
                name       = 'platform-api'
                clone_url  = 'https://github.com/example/platform-api.git'
            }

            [WorkspaceRepository]@{
                repository = 'example/platform-web'
                name       = 'platform-web'
                clone_url  = 'https://github.com/example/platform-web.git'
            }
        )

        $workspace = Resolve-Workspace -Repositories $repositories
    }

    It 'resolves repository data into a Workspace' {
        $workspace | Should -BeOfType ([Workspace])
        $workspace.root | Should -Be '/workspaces'
        $workspace.children | Should -HaveCount 4
    }

    It 'resolves standalone repositories as repository nodes' {
        $node = $workspace.children |
            Where-Object { $_.type -eq 'repository' -and $_.name -eq 'api' }

        $node | Should -Not -BeNullOrEmpty
        $node | Should -BeOfType ([WorkspaceRepository])
        $node.repository | Should -Be 'example/api'
        $node.name | Should -Be 'api'
        $node.path | Should -Be 'api'
        $node.clone_url | Should -Be 'https://github.com/example/api.git'
    }

    It 'resolves shared repository prefixes as logical parents' {
        $node = $workspace.children |
            Where-Object { $_.type -eq 'logical_parent' -and $_.name -eq 'platform' }

        $node | Should -Not -BeNullOrEmpty
        $node | Should -BeOfType ([WorkspaceLogicalParent])
        $node.path | Should -Be 'platform'
        $node.children | Should -HaveCount 2
    }

    It 'resolves logical parent repository paths' {
        $node = $workspace.children |
            Where-Object { $_.type -eq 'logical_parent' -and $_.name -eq 'platform' }

        $api = $node.children |
            Where-Object { $_.name -eq 'api' }

        $web = $node.children |
            Where-Object { $_.name -eq 'web' }

        $api.path | Should -Be 'platform/api'
        $web.path | Should -Be 'platform/web'
    }

    It 'builds the resolved Workspace' {
        Build-Workspace -Workspace $workspace

        $workspacePath = Join-Path $workspaceRoot ''
        
        $workspacePath | Should -Exist
    }
}