BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/proxies/Resolve-AmiaseaRequiredResource.ps1')
}

Describe 'Resolve-AmiaseaRequiredResource' {

    It 'resolves dependencies from an Amiasea resource' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'PowerShellForGitHub'
                        VersionRange = '[0.17.0,0.18.0)'
                        Repository   = 'PSGallery'
                    }
                    [pscustomobject]@{
                        Name         = 'Amiasea.Shared'
                        VersionRange = '[2.0.0,3.0.0)'
                        Repository   = 'Amiasea'
                    }
                )
            }
        }

        $result = Resolve-AmiaseaRequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3'

        $result.Keys |
            Should -Contain 'PowerShellForGitHub'

        $result.Keys |
            Should -Contain 'Amiasea.Shared'

        $result['PowerShellForGitHub'].version |
            Should -Be '[0.17.0,0.18.0)'

        $result['PowerShellForGitHub'].repository |
            Should -Be 'PSGallery'

        $result['Amiasea.Shared'].version |
            Should -Be '[2.0.0,3.0.0)'

        $result['Amiasea.Shared'].repository |
            Should -Be 'Amiasea'
    }

    It 'passes the requested name and version to Find-PSResource' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @()
            }
        }

        $result = Resolve-AmiaseaRequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Amiasea.Workspace' -and
                $Version -eq '1.2.3' -and
                $Repository -eq 'Amiasea' -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'does not include dependencies without a name' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = $null
                        VersionRange = '[1.0.0,2.0.0)'
                        Repository   = 'Amiasea'
                    }
                )
            }
        }

        $result = Resolve-AmiaseaRequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3'

        $result | Should -BeNullOrEmpty
    }

    It 'rejects a dependency without a VersionRange' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'Amiasea.Shared'
                        VersionRange = $null
                        Repository   = 'Amiasea'
                    }
                )
            }
        }

        {
            Resolve-AmiaseaRequiredResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.2.3'
        } | Should -Throw `
            "Resolver invariant violated: dependency 'Amiasea.Shared' has no VersionRange."
    }

    It 'rejects a missing root resource' {
        Mock Find-PSResource {
            $null
        }

        {
            Resolve-AmiaseaRequiredResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.2.3'
        } | Should -Throw `
            "Amiasea resource 'Amiasea.Workspace' could not be found."
    }

    It 'rejects a root resource with the wrong name' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Other'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @()
            }
        }

        {
            Resolve-AmiaseaRequiredResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.2.3'
        } | Should -Throw `
            "Resolver invariant violated: requested 'Amiasea.Workspace', but Find-PSResource returned 'Amiasea.Other'."
    }

    It 'rejects a root resource with the wrong version' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '2.0.0'
                Prerelease   = $null
                Dependencies = @()
            }
        }

        {
            Resolve-AmiaseaRequiredResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.2.3'
        } | Should -Throw `
            "Resolver invariant violated: requested version '1.2.3', but Find-PSResource returned '2.0.0'."
    }

    It 'preserves a dependency repository when one is supplied' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'Amiasea.Shared'
                        VersionRange = '2.0.0'
                        Repository   = 'Amiasea'
                    }
                )
            }
        }

        $result = Resolve-AmiaseaRequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3'

        $result['Amiasea.Shared'].repository |
            Should -Be 'Amiasea'
    }

    It 'resolves a dependency repository when one is not supplied' {
        Mock Find-PSResource {
            param(
                [string]$Name,
                [object]$Version,
                [string]$Repository
            )

            if ($Name -eq 'Amiasea.Workspace') {
                return [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'PowerShellForGitHub'
                            VersionRange = '[0.17.0,0.18.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            if ($Name -eq 'PowerShellForGitHub') {
                return [pscustomobject]@{
                    Name         = 'PowerShellForGitHub'
                    Version      = '0.17.0'
                    Prerelease   = $null
                    Dependencies = @()
                    Repository   = 'PSGallery'
                }
            }
        }

        $result = Resolve-AmiaseaRequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3'

        $result['PowerShellForGitHub'].version |
            Should -Be '[0.17.0,0.18.0)'

        $result['PowerShellForGitHub'].ContainsKey('repository') |
            Should -BeTrue

        $result['PowerShellForGitHub'].repository |
            Should -Be 'PSGallery'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'PowerShellForGitHub' -and
                $Version -eq '[0.17.0,0.18.0)' -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'requires every dependency to have an explicit repository' {
        Mock Find-PSResource {
            param(
                [string]$Name
            )

            if ($Name -eq 'Amiasea.Workspace') {
                return [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'PowerShellForGitHub'
                            VersionRange = '[0.17.0,0.18.0)'
                            Repository   = $null
                        }
                        [pscustomobject]@{
                            Name         = 'Amiasea.Shared'
                            VersionRange = '[2.0.0,3.0.0)'
                            Repository   = 'Amiasea'
                        }
                    )
                }
            }

            if ($Name -eq 'PowerShellForGitHub') {
                return [pscustomobject]@{
                    Name         = 'PowerShellForGitHub'
                    Version      = '0.17.0'
                    Prerelease   = $null
                    Dependencies = @()
                    Repository   = 'PSGallery'
                }
            }
        }

        $result = Resolve-AmiaseaRequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3'

        foreach ($dependencyName in $result.Keys) {
            $result[$dependencyName].ContainsKey('repository') |
                Should -BeTrue

            $result[$dependencyName].repository |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'rejects a dependency that cannot be resolved to a repository' {
        Mock Find-PSResource {
            param(
                [string]$Name
            )

            if ($Name -eq 'Amiasea.Workspace') {
                return [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Unknown.Dependency'
                            VersionRange = '[1.0.0,2.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            $null
        }

        try {
            Resolve-AmiaseaRequiredResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.2.3'

            throw 'Expected Resolve-AmiaseaRequiredResource to throw.'
        }
        catch {
            $_.Exception.Message |
                Should -Be "Dependency 'Unknown.Dependency' with version '[1.0.0,2.0.0)' could not be found in any registered repository."
        }
    }

    It 'rejects a dependency resource that has no repository' {
        Mock Find-PSResource {
            param(
                [string]$Name
            )

            if ($Name -eq 'Amiasea.Workspace') {
                return [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Unknown.Dependency'
                            VersionRange = '[1.0.0,2.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            if ($Name -eq 'Unknown.Dependency') {
                return [pscustomobject]@{
                    Name         = 'Unknown.Dependency'
                    Version      = '1.0.0'
                    Prerelease   = $null
                    Dependencies = @()
                    Repository   = $null
                }
            }
        }

        {
            Resolve-AmiaseaRequiredResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.2.3'
        } | Should -Throw `
            "Resolver invariant violated: dependency 'Unknown.Dependency' resolved without a repository."
    }
}