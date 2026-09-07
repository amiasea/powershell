using module ../../.build/Proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../.build/Proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'ConvertTo-AmiaseaInstallParameters' {

    It 'does not intercept a non-Amiasea resource' {
        InModuleScope Amiasea.Proxies {
            $result = ConvertTo-AmiaseaInstallParameters @{
                Name = 'Some.OtherResource'
            }

            $result | Should -BeNullOrEmpty
        }
    }

    It 'rejects multiple Amiasea resources' {
        InModuleScope Amiasea.Proxies {
            {
                ConvertTo-AmiaseaInstallParameters @{
                    Name = @(
                        'Amiasea.Workspace'
                        'Amiasea.Shared'
                    )
                }
            } | Should -Throw `
                'Install-PSResource proxy currently supports exactly one Amiasea resource per invocation.'
        }
    }

    It 'resolves an Amiasea resource from the Amiasea repository' {
        InModuleScope Amiasea.Proxies {
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

            $result = ConvertTo-AmiaseaInstallParameters @{
                Name = 'Amiasea.Workspace'
            }

            Should -Invoke Find-PSResource `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Repository -eq 'Amiasea'
                }

            Should -Invoke Resolve-AmiaseaRequiredResource `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Version -eq '1.2.3'
                }
        }
    }

    It 'forwards an explicit version to Find-PSResource' {
        InModuleScope Amiasea.Proxies {
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

            $result = ConvertTo-AmiaseaInstallParameters @{
                Name    = 'Amiasea.Workspace'
                Version = '1.2.3'
            }

            Should -Invoke Find-PSResource `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Repository -eq 'Amiasea' -and
                    $Version -eq '1.2.3'
                }
        }
    }

    It 'forwards Prerelease to Find-PSResource' {
        InModuleScope Amiasea.Proxies {
            Mock Find-PSResource {
                [pscustomobject]@{
                    Name         = 'Amiasea.Workspace'
                    Version      = '1.2.3'
                    Prerelease   = 'preview.1'
                    Dependencies = @()
                }
            }

            Mock Resolve-AmiaseaRequiredResource {
                return ,@{}
            }

            $result = ConvertTo-AmiaseaInstallParameters @{
                Name        = 'Amiasea.Workspace'
                Prerelease  = $true
            }

            Should -Invoke Find-PSResource `
                -Times 1 `
                -Exactly `
                -ParameterFilter {
                    $Name -eq 'Amiasea.Workspace' -and
                    $Repository -eq 'Amiasea' -and
                    $Prerelease
                }
        }
    }

    It 'forces the Amiasea repository in the resulting RequiredResource' {
        InModuleScope Amiasea.Proxies {
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

            $result = ConvertTo-AmiaseaInstallParameters @{
                Name       = 'Amiasea.Workspace'
                Repository = 'PSGallery'
            }

            $result.RequiredResource['Amiasea.Workspace'].repository |
                Should -Be 'Amiasea'
        }
    }

    It 'uses the selected Amiasea version in RequiredResource' {
        InModuleScope Amiasea.Proxies {
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

            $result = ConvertTo-AmiaseaInstallParameters @{
                Name = 'Amiasea.Workspace'
            }

            $result.RequiredResource['Amiasea.Workspace'].version |
                Should -Be '1.2.3'
        }
    }

    It 'adds resolved dependencies to RequiredResource' {
        InModuleScope Amiasea.Proxies {
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
                        version    = '0.17.0'
                        repository = 'PSGallery'
                    }
                    'Amiasea.Shared' = @{
                        version    = '2.0.0'
                        repository = 'Amiasea'
                    }
                }
            }

            $result = ConvertTo-AmiaseaInstallParameters @{
                Name = 'Amiasea.Workspace'
            }

            $result.RequiredResource.Keys |
                Should -Contain 'PowerShellForGitHub'

            $result.RequiredResource.Keys |
                Should -Contain 'Amiasea.Shared'

            $result.RequiredResource['PowerShellForGitHub'].version |
                Should -Be '0.17.0'

            $result.RequiredResource['Amiasea.Shared'].version |
                Should -Be '2.0.0'
        }
    }

    It 'does not intercept an invocation using RequiredResource' {
        InModuleScope Amiasea.Proxies {
            Mock Find-PSResource {
                throw 'Find-PSResource should not have been called.'
            }

            $result = ConvertTo-AmiaseaInstallParameters @{
                RequiredResource = @{
                    'Amiasea.Workspace' = @{
                        version    = '1.2.3'
                        repository = 'Amiasea'
                    }
                }
            }

            $result | Should -BeNullOrEmpty

            Should -Invoke Find-PSResource `
                -Times 0 `
                -Exactly
        }
    }

    It 'does not intercept an invocation using RequiredResourceFile' {
        InModuleScope Amiasea.Proxies {
            Mock Find-PSResource {
                throw 'Find-PSResource should not have been called.'
            }

            $result = ConvertTo-AmiaseaInstallParameters @{
                RequiredResourceFile = 'required.psd1'
            }

            $result | Should -BeNullOrEmpty

            Should -Invoke Find-PSResource `
                -Times 0 `
                -Exactly
        }
    }
}