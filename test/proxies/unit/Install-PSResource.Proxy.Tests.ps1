BeforeAll {
    . (Join-Path `
        $PSScriptRoot `
        '../../../src/proxies/Resolve-RequiredResource.ps1')

    . (Join-Path `
        $PSScriptRoot `
        '../../../src/proxies/ConvertTo-AmiaseaInstallParameters.ps1')

    . (Join-Path `
        $PSScriptRoot `
        '../../../src/proxies/Install-PSResource.Proxy.ps1')

    $installPSResourceCommand = Get-Command `
        -Name Install-PSResource `
        -CommandType Function `
        -ErrorAction Stop
}

Describe 'Install-PSResource proxy' {

    It 'exposes UseExternalDependencyResolution' {
        $installPSResourceCommand.Parameters.ContainsKey(
            'UseExternalDependencyResolution'
        ) |
            Should -BeTrue
    }

    It 'invokes external dependency resolution when requested' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            throw 'STOP AFTER CONVERTER'
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -UseExternalDependencyResolution
        } |
            Should -Throw 'STOP AFTER CONVERTER'

        Should -Invoke `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' `
            -Times 1 `
            -Exactly
    }

    It 'passes Name to external dependency resolution' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            throw 'STOP AFTER CONVERTER'
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -UseExternalDependencyResolution
        } |
            Should -Throw 'STOP AFTER CONVERTER'

        Should -Invoke `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $BoundParameters['Name'] -eq 'Amiasea.Test'
            }
    }

    It 'passes Version to external dependency resolution when specified' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            throw 'STOP AFTER CONVERTER'
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -Version '1.2.3' `
                -UseExternalDependencyResolution
        } |
            Should -Throw 'STOP AFTER CONVERTER'

        Should -Invoke `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $BoundParameters['Name'] -eq 'Amiasea.Test' -and
                $BoundParameters['Version'] -eq '1.2.3'
            }
    }

    It 'passes Prerelease to external dependency resolution when specified' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            throw 'STOP AFTER CONVERTER'
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -Prerelease `
                -UseExternalDependencyResolution
        } |
            Should -Throw 'STOP AFTER CONVERTER'

        Should -Invoke `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $BoundParameters['Name'] -eq 'Amiasea.Test' -and
                $BoundParameters['Prerelease'] -eq $true
            }
    }

    It 'does not pass Repository to external dependency resolution' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            throw 'STOP AFTER CONVERTER'
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -Repository 'PSGallery' `
                -UseExternalDependencyResolution
        } |
            Should -Throw 'STOP AFTER CONVERTER'

        Should -Invoke `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $BoundParameters['Name'] -eq 'Amiasea.Test' -and
                -not $BoundParameters.ContainsKey('Repository')
            }
    }

    It 'does not pass unrelated native parameters to external dependency resolution' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            throw 'STOP AFTER CONVERTER'
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -Version '1.2.3' `
                -Scope CurrentUser `
                -TrustRepository `
                -UseExternalDependencyResolution
        } |
            Should -Throw 'STOP AFTER CONVERTER'

        Should -Invoke `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $BoundParameters['Name'] -eq 'Amiasea.Test' -and
                $BoundParameters['Version'] -eq '1.2.3' -and
                -not $BoundParameters.ContainsKey('Scope') -and
                -not $BoundParameters.ContainsKey('TrustRepository') -and
                -not $BoundParameters.ContainsKey('Repository')
            }
    }

    It 'throws when external resolution returns no installation request' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            return $null
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -UseExternalDependencyResolution
        } |
            Should -Throw `
                'External dependency resolution did not produce an Amiasea installation request.'
    }

    It 'throws when external resolution does not produce RequiredResource' {
        Mock `
            -CommandName 'ConvertTo-AmiaseaInstallParameters' {
            return @{}
        }

        {
            & $installPSResourceCommand.ScriptBlock `
                -Name 'Amiasea.Test' `
                -UseExternalDependencyResolution
        } |
            Should -Throw `
                'External dependency resolution did not produce RequiredResource entries.'
    }
}