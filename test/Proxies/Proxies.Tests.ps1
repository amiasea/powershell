using module ../../.build/Proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../.build/Proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Proxies' {

    Context 'Resolve-AmiaseaRequiredResource' {

        It 'resolves an Amiasea resource from the Amiasea repository' {
            InModuleScope Amiasea.Proxies {
                Mock Find-PSResource {
                    [pscustomobject]@{
                        Name         = 'Amiasea.Workspace'
                        Version      = '1.2.3'
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
                        $Repository -eq 'Amiasea'
                    }

                Should -BeOfType -ExpectedType ([hashtable]) -ActualValue $result
                $result.Count | Should -Be 0
            }
        }

        It 'returns dependency metadata as RequiredResource entries' {
            InModuleScope Amiasea.Proxies {
                Mock Find-PSResource {
                    [pscustomobject]@{
                        Name         = 'Amiasea.Workspace'
                        Version      = '1.2.3'
                        Dependencies = @(
                            [pscustomobject]@{
                                Name       = 'PowerShellForGitHub'
                                Version    = '0.17.0'
                                Repository = 'PSGallery'
                            },
                            [pscustomobject]@{
                                Name       = 'Amiasea.Shared'
                                Version    = '2.0.0'
                                Repository = 'Amiasea'
                            }
                        )
                    }
                }

                $result = Resolve-AmiaseaRequiredResource `
                    -Name 'Amiasea.Workspace' `
                    -Version '1.2.3'

                $result.Keys | Should -Contain 'PowerShellForGitHub'
                $result.Keys | Should -Contain 'Amiasea.Shared'

                $result['PowerShellForGitHub'].version |
                    Should -Be '0.17.0'

                $result['PowerShellForGitHub'].repository |
                    Should -Be 'PSGallery'

                $result['Amiasea.Shared'].version |
                    Should -Be '2.0.0'

                $result['Amiasea.Shared'].repository |
                    Should -Be 'Amiasea'
            }
        }

        It 'omits dependencies without a name' {
            InModuleScope Amiasea.Proxies {
                Mock Find-PSResource {
                    [pscustomobject]@{
                        Name         = 'Amiasea.Workspace'
                        Version      = '1.2.3'
                        Dependencies = @(
                            [pscustomobject]@{
                                Name       = $null
                                Version    = '1.0.0'
                                Repository = 'PSGallery'
                            }
                        )
                    }
                }

                $result = Resolve-AmiaseaRequiredResource `
                    -Name 'Amiasea.Workspace' `
                    -Version '1.2.3'

                $result.Count | Should -Be 0
            }
        }

        It 'throws when the Amiasea resource cannot be found' {
            InModuleScope Amiasea.Proxies {
                Mock Find-PSResource {
                    $null
                }

                {
                    Resolve-AmiaseaRequiredResource `
                        -Name 'Amiasea.Missing' `
                        -Version '1.2.3'
                } | Should -Throw "Amiasea resource 'Amiasea.Missing' could not be found."
            }
        }
    }

    Context 'Install-PSResource proxy' {

        It 'does not resolve non-Amiasea resources' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                throw 'Find-PSResource should not have been called.'
            }

            Mock 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' -ModuleName Amiasea.Proxies {
                return
            }

            {
                Install-PSResource `
                    -Name 'Some.OtherResource' `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Find-PSResource `
                -ModuleName Amiasea.Proxies `
                -Times 0 `
                -Exactly

            Should -Invoke 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly
        }

        It 'does not resolve an Amiasea resource when RequiredResource is supplied' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                throw 'Find-PSResource should not have been called.'
            }

            Mock 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' -ModuleName Amiasea.Proxies {
                return
            }

            $requiredResource = @{
                'Amiasea.Workspace' = @{
                    version    = '1.2.3'
                    repository = 'Amiasea'
                }
            }

            {
                Install-PSResource `
                    -RequiredResource $requiredResource `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Find-PSResource `
                -ModuleName Amiasea.Proxies `
                -Times 0 `
                -Exactly

            Should -Invoke 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly
        }

        It 'does not resolve an Amiasea resource when RequiredResourceFile is supplied' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                throw 'Find-PSResource should not have been called.'
            }

            Mock 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' -ModuleName Amiasea.Proxies {
                return
            }

            $requiredResourceFile = Join-Path $TestDrive 'required.psd1'

            Set-Content -Path $requiredResourceFile -Value @'
@{
    Amiasea_Workspace = @{
        version = '1.2.3'
    }
}
'@

            {
                Install-PSResource `
                    -RequiredResourceFile $requiredResourceFile `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Find-PSResource `
                -ModuleName Amiasea.Proxies `
                -Times 0 `
                -Exactly

            Should -Invoke 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly
        }

        It 'rejects multiple Amiasea resources in one invocation' {
            {
                Install-PSResource `
                    -Name @(
                        'Amiasea.Workspace'
                        'Amiasea.Shared'
                    )
            } | Should -Throw `
                'Install-PSResource proxy currently supports exactly one Amiasea resource per invocation.'
        }

        It 'forwards an explicit version to Find-PSResource' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @()
                }
            }

            Mock Resolve-AmiaseaRequiredResource -ModuleName Amiasea.Proxies {
                return ,@{}
            }

            {
                Install-PSResource `
                    -Name 'Amiasea.Workspace' `
                    -Version '1.2.3' `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Find-PSResource `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Repository -eq 'Amiasea' -and
                    $Version -eq '1.2.3'
                }
        }

        It 'forwards Prerelease to Find-PSResource' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = 'preview.1'
                    Dependencies = @()
                }
            }

            Mock Resolve-AmiaseaRequiredResource -ModuleName Amiasea.Proxies {
                return ,@{}
            }

            {
                Install-PSResource `
                    -Name 'Amiasea.Workspace' `
                    -Prerelease `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Find-PSResource `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Repository -eq 'Amiasea' -and
                    $Prerelease
                }
        }

        It 'uses the selected Amiasea version when resolving dependencies' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @()
                }
            }

            Mock Resolve-AmiaseaRequiredResource -ModuleName Amiasea.Proxies {
                return ,@{}
            }

            {
                Install-PSResource `
                    -Name 'Amiasea.Workspace' `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Resolve-AmiaseaRequiredResource `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Version -eq '1.2.3'
                }
        }

        It 'uses the Amiasea repository when resolving an Amiasea resource' {
            Mock Find-PSResource -ModuleName Amiasea.Proxies {
                [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = $null
                    Dependencies = @()
                }
            }

            Mock Resolve-AmiaseaRequiredResource -ModuleName Amiasea.Proxies {
                return ,@{}
            }

            {
                Install-PSResource `
                    -Name 'Amiasea.Workspace' `
                    -Repository 'PSGallery' `
                    -WhatIf
            } | Should -Not -Throw

            Should -Invoke Find-PSResource `
                -ModuleName Amiasea.Proxies `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Repository -eq 'Amiasea'
                }
        }
    }
}