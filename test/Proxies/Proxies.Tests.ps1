using module ../../.build/Proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../.build/Proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Proxies' {

    It 'registers Install-PSResource as a function' {
        InModuleScope Amiasea.Proxies {
            $command = Get-Command Install-PSResource

            $command.CommandType | Should -Be 'Function'
        }
    }

    It 'registers Resolve-AmiaseaRequiredResource' {
        InModuleScope Amiasea.Proxies {
            Get-Command Resolve-AmiaseaRequiredResource |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'registers ConvertTo-AmiaseaInstallParameters' {
        InModuleScope Amiasea.Proxies {
            Get-Command ConvertTo-AmiaseaInstallParameters |
                Should -Not -BeNullOrEmpty
        }
    }
}