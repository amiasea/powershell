# Install-PSResource with no external-resolution switch; proves the proxy preserves native PSResourceGet behavior
using module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Install-PSResource native route' {

    BeforeEach {
        Mock `
            -CommandName 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
            -MockWith {}
    }

    It 'invokes the native Install-PSResource command without external dependency resolution' {
        {
            Amiasea.Proxies\Install-PSResource `
                -Name 'Amiasea.Test' `
                -WhatIf `
                -ErrorAction Stop
        } |
            Should -Not -Throw

        Should -Invoke `
            -CommandName 'Microsoft.PowerShell.PSResourceGet\Install-PSResource' `
            -Times 1 `
            -Exactly
    }
}