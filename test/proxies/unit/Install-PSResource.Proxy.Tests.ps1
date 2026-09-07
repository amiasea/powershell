BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/proxies/Resolve-AmiaseaRequiredResource.ps1')
    . (Join-Path $PSScriptRoot '../../../src/proxies/ConvertTo-AmiaseaInstallParameters.ps1')

    #
    # Capture the generated proxy function definition so the tests can
    # inspect the actual invocation boundary without replacing the native
    # PSResourceGet cmdlet.
    #
    $proxyPath = Join-Path `
        $PSScriptRoot `
        '../../../src/proxies/Install-PSResource.Proxy.ps1'

    $proxySource = Get-Content `
        -Path $proxyPath `
        -Raw

    #
    # The proxy source creates the final Install-PSResource function at
    # load time. Execute it once so the function exists for structural
    # inspection and invocation tests.
    #
    . $proxyPath

    $installPSResourceCommand = Get-Command `
        -Name Install-PSResource `
        -CommandType Function `
        -ErrorAction Stop

    $installPSResourceDefinition = $installPSResourceCommand.Definition
}

Describe 'Install-PSResource proxy' {

    It 'invokes the wrapped native command with PSBoundParameters' {
        $installPSResourceDefinition |
            Should -Match '\& \$wrappedCmd @PSBoundParameters'
    }

    It 'replaces Amiasea installation parameters with RequiredResource before native invocation' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @()
            }
        }

        Mock Resolve-AmiaseaRequiredResource {
            return @{
                'PowerShellForGitHub' = @{
                    version    = '[0.17.0,)'
                    repository = 'PSGallery'
                }
            }
        }

        $parameters = @{
            Name  = 'Amiasea.Workspace'
            Scope = 'CurrentUser'
        }

        $result = ConvertTo-AmiaseaInstallParameters `
            -BoundParameters $parameters

        $result |
            Should -Not -BeNullOrEmpty

        $result.ContainsKey('Name') |
            Should -BeFalse

        $result.ContainsKey('Version') |
            Should -BeFalse

        $result.ContainsKey('Repository') |
            Should -BeFalse

        $result.ContainsKey('RequiredResource') |
            Should -BeTrue

        $result.RequiredResource.ContainsKey('Amiasea.Workspace') |
            Should -BeTrue

        $result.RequiredResource['Amiasea.Workspace'].version |
            Should -Be '1.2.3'

        $result.RequiredResource['Amiasea.Workspace'].repository |
            Should -Be 'Amiasea'

        $result.RequiredResource.ContainsKey('PowerShellForGitHub') |
            Should -BeTrue

        $result.RequiredResource['PowerShellForGitHub'].version |
            Should -Be '[0.17.0,)'

        $result.RequiredResource['PowerShellForGitHub'].repository |
            Should -Be 'PSGallery'

        $result.Scope |
            Should -Be 'CurrentUser'
    }

    It 'does not transform a native invocation that already uses RequiredResource' {
        Mock Find-PSResource {
            throw 'Find-PSResource should not be called.'
        }

        $parameters = @{
            RequiredResource = @{
                'Amiasea.Workspace' = @{
                    version    = '1.2.3'
                    repository = 'Amiasea'
                }
                'PowerShellForGitHub' = @{
                    version    = '[0.17.0,)'
                    repository = 'PSGallery'
                }
            }
            Scope = 'CurrentUser'
        }

        $result = ConvertTo-AmiaseaInstallParameters `
            -BoundParameters $parameters

        $result |
            Should -BeNullOrEmpty

        Should -Invoke Find-PSResource `
            -Times 0 `
            -Exactly
    }

    It 'preserves native parameters alongside the transformed RequiredResource' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @()
            }
        }

        Mock Resolve-AmiaseaRequiredResource {
            return ,@{}
        }

        $result = ConvertTo-AmiaseaInstallParameters `
            -BoundParameters @{
                Name          = 'Amiasea.Workspace'
                Scope         = 'CurrentUser'
                TrustRepository = $true
            }

        $result.RequiredResource |
            Should -Not -BeNullOrEmpty

        $result.RequiredResource['Amiasea.Workspace'].version |
            Should -Be '1.2.3'

        $result.RequiredResource['Amiasea.Workspace'].repository |
            Should -Be 'Amiasea'

        $result.Scope |
            Should -Be 'CurrentUser'

        $result.TrustRepository |
            Should -BeTrue
    }

    It 'does not leave Name, Version, or Repository at the top level of the transformed parameters' {
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $null
                Dependencies = @()
            }
        }

        Mock Resolve-AmiaseaRequiredResource {
            return ,@{}
        }

        $result = ConvertTo-AmiaseaInstallParameters `
            -BoundParameters @{
                Name       = 'Amiasea.Workspace'
                Version    = '1.2.3'
                Repository = 'PSGallery'
            }

        $result.ContainsKey('Name') |
            Should -BeFalse

        $result.ContainsKey('Version') |
            Should -BeFalse

        $result.ContainsKey('Repository') |
            Should -BeFalse

        $result.ContainsKey('RequiredResource') |
            Should -BeTrue
    }
}