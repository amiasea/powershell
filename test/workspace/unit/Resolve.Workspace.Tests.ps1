using module ../../../src/workspace/Workspace.Types.psm1
using module ../../../src/workspace/Workspace.psm1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../src/workspace/Workspace.psm1'

    Import-Module $modulePath -Force
}

Describe 'Resolve-Workspace' {
    BeforeEach {
        $repositories = @(
            [pscustomobject]@{
                Name     = 'api'
                CloneUrl = 'https://github.com/example/api.git'
            }

            [pscustomobject]@{
                Name     = 'web'
                CloneUrl = 'https://github.com/example/web.git'
            }

            [pscustomobject]@{
                Name     = 'platform-api'
                CloneUrl = 'https://github.com/example/platform-api.git'
            }

            [pscustomobject]@{
                Name     = 'platform-web'
                CloneUrl = 'https://github.com/example/platform-web.git'
            }
        )

        Mock `
            -CommandName Get-GitHubRepository `
            -ModuleName Workspace `
            -MockWith {
                $repositories
            }
    }

    It 'resolves repository data into a Workspace' {
        $workspace = Resolve-Workspace -Organization 'example'

        $workspace.GetType().Name | Should -Be 'Workspace'
        $workspace.root | Should -Be '/workspaces'
        $workspace.children | Should -HaveCount 3
    }

    It 'resolves standalone repositories as repository nodes' {
        $workspace = Resolve-Workspace -Organization 'example'

        $node = $workspace.children |
            Where-Object {
                $_.type -eq 'repository' -and
                $_.name -eq 'api'
            }

        $node | Should -Not -BeNullOrEmpty
        $node.GetType().Name | Should -Be 'WorkspaceRepository'
        $node.GetType().BaseType.Name | Should -Be 'WorkspaceChild'
        $node.repository | Should -Be 'example/api'
        $node.name | Should -Be 'api'
        $node.path | Should -Be 'api'
        $node.clone_url | Should -Be 'https://github.com/example/api.git'
    }

    It 'resolves shared repository prefixes as logical parents' {
        $workspace = Resolve-Workspace -Organization 'example'

        $node = $workspace.children |
            Where-Object {
                $_.type -eq 'logical_parent' -and
                $_.name -eq 'platform'
            }

        $node | Should -Not -BeNullOrEmpty
        $node.GetType().Name | Should -Be 'WorkspaceLogicalParent'
        $node.GetType().BaseType.Name | Should -Be 'WorkspaceChild'
        $node.path | Should -Be 'platform'
        $node.children | Should -HaveCount 2
    }

    It 'resolves logical parent repository paths' {
        $workspace = Resolve-Workspace -Organization 'example'

        $node = $workspace.children |
            Where-Object {
                $_.type -eq 'logical_parent' -and
                $_.name -eq 'platform'
            }

        $api = $node.children |
            Where-Object { $_.name -eq 'api' }

        $web = $node.children |
            Where-Object { $_.name -eq 'web' }

        $api.path | Should -Be 'platform/api'
        $web.path | Should -Be 'platform/web'
    }

    It 'queries GitHub using the specified organization' {
        Resolve-Workspace -Organization 'example' | Out-Null

        Should -Invoke `
            -CommandName Get-GitHubRepository `
            -ModuleName Workspace `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $OrganizationName -eq 'example'
            }
    }
}