using module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Proxies' {

    It 'registers Install-PSResource as a function' {
        InModuleScope Amiasea.Proxies {
            $command = Get-Command Install-PSResource

            $command.CommandType |
                Should -Be 'Function'
        }
    }

    It 'registers Resolve-AmiaseaRequiredResource inside the module' {
        InModuleScope Amiasea.Proxies {
            Get-Command Resolve-AmiaseaRequiredResource |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'registers ConvertTo-AmiaseaInstallParameters inside the module' {
        InModuleScope Amiasea.Proxies {
            Get-Command ConvertTo-AmiaseaInstallParameters |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'exports Install-PSResource' {
        $module = Get-Module Amiasea.Proxies

        $module.ExportedFunctions.Keys |
            Should -Contain 'Install-PSResource'
    }

    It 'does not export Resolve-AmiaseaRequiredResource' {
        $module = Get-Module Amiasea.Proxies

        $module.ExportedFunctions.Keys |
            Should -Not -Contain 'Resolve-AmiaseaRequiredResource'
    }

    It 'does not export ConvertTo-AmiaseaInstallParameters' {
        $module = Get-Module Amiasea.Proxies

        $module.ExportedFunctions.Keys |
            Should -Not -Contain 'ConvertTo-AmiaseaInstallParameters'
    }
}