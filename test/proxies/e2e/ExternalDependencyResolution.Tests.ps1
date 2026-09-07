# -UseExternalDependencyResolution end-to-end behavior;
# converter → resolver → explicit RequiredResource → native installation
using module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Install-PSResource external dependency resolution' {

    BeforeEach {
        $rootResource = [pscustomobject]@{
            Name         = 'Amiasea.Workspace'
            Version      = [version]'1.0.43'
            Repository   = 'Amiasea'
            Dependencies = @(
                [pscustomobject]@{
                    Name         = 'PowerShellForGitHub'
                    VersionRange = '[0.17.0, )'
                    Repository   = $null
                }
            )
        }

        $dependencyResource = [pscustomobject]@{
            Name       = 'PowerShellForGitHub'
            Version    = [version]'0.17.0'
            Repository = 'PSGallery'
        }

        Mock `
            -ModuleName Amiasea.Proxies `
            -CommandName Find-PSResource `
            -MockWith {
                switch ($Name) {
                    'Amiasea.Workspace' {
                        $rootResource
                        break
                    }

                    'PowerShellForGitHub' {
                        $dependencyResource
                        break
                    }

                    default {
                        throw "Unexpected Find-PSResource request: $Name"
                    }
                }
            }

        Mock `
            -CommandName 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
            -MockWith {}
    }

    It 'uses external dependency resolution before native installation' {
        Amiasea.Proxies\Install-PSResource `
            -Name 'Amiasea.Workspace' `
            -UseExternalDependencyResolution `
            -WhatIf `
            -ErrorAction Stop

        Should -Invoke `
            -CommandName Find-PSResource `
            -ModuleName Amiasea.Proxies `
            -Times 3 `
            -Exactly

        Should -Invoke `
            -CommandName 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
            -Times 1 `
            -Exactly
    }

    It 'does not resolve the Amiasea root when an explicit version is supplied' {
        Amiasea.Proxies\Install-PSResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.0.43' `
            -UseExternalDependencyResolution `
            -WhatIf `
            -ErrorAction Stop

        Should -Invoke `
            -CommandName Find-PSResource `
            -ModuleName Amiasea.Proxies `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'PowerShellForGitHub'
            }

        Should -Invoke `
            -CommandName 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
            -Times 1 `
            -Exactly
    }
}