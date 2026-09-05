BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../.build/Workspace/out/Workspace.psd1'

    Import-Module $modulePath -Force
}

Describe 'Workspace' {
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

        $workspace | Should -BeOfType ([Workspace])
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
        $node | Should -BeOfType ([WorkspaceRepository])
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
        $node | Should -BeOfType ([WorkspaceLogicalParent])
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

    It 'builds the resolved Workspace' {
        $workspace = Resolve-Workspace -Organization 'example'

        $workspaceRoot = Join-Path $TestDrive 'workspaces'

        $workspace.root = $workspaceRoot

        Mock `
            -CommandName git `
            -ModuleName Workspace `
            -MockWith {
                $global:LASTEXITCODE = 0
            }

        Build-Workspace -Workspace $workspace

        $workspaceRoot | Should -Exist

        Should -Invoke `
            -CommandName git `
            -ModuleName Workspace `
            -Times 3 `
            -Exactly `
            -ParameterFilter {
                $args[0] -eq 'clone'
            }
    }
}