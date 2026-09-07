# Built/published module surface: exports, command type, private functions, manifest/package loadingusing module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Amiasea.Proxies module' {

    It 'loads the published module' {
        $module = Get-Module Amiasea.Proxies

        $module |
            Should -Not -BeNullOrEmpty
    }

    It 'registers Install-PSResource as a function' {
        InModuleScope Amiasea.Proxies {
            $command = Get-Command `
                -Name Install-PSResource `
                -ErrorAction Stop

            $command.CommandType |
                Should -Be 'Function'
        }
    }

    It 'exports Install-PSResource' {
        $module = Get-Module Amiasea.Proxies

        $module.ExportedFunctions.Keys |
            Should -Contain 'Install-PSResource'
    }

    It 'does not export Resolve-RequiredResource' {
        $module = Get-Module Amiasea.Proxies

        $module.ExportedFunctions.Keys |
            Should -Not -Contain 'Resolve-RequiredResource'
    }

    It 'does not export ConvertTo-AmiaseaInstallParameters' {
        $module = Get-Module Amiasea.Proxies

        $module.ExportedFunctions.Keys |
            Should -Not -Contain 'ConvertTo-AmiaseaInstallParameters'
    }

    It 'registers Resolve-RequiredResource inside the module' {
        InModuleScope Amiasea.Proxies {
            Get-Command `
                -Name Resolve-RequiredResource `
                -ErrorAction Stop |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'registers ConvertTo-AmiaseaInstallParameters inside the module' {
        InModuleScope Amiasea.Proxies {
            Get-Command `
                -Name ConvertTo-AmiaseaInstallParameters `
                -ErrorAction Stop |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'exposes UseExternalDependencyResolution on Install-PSResource' {
        InModuleScope Amiasea.Proxies {
            $command = Get-Command `
                -Name Install-PSResource `
                -ErrorAction Stop

            $command.Parameters.ContainsKey(
                'UseExternalDependencyResolution'
            ) |
                Should -BeTrue
        }
    }
}