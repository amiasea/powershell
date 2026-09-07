# Install-PSResource with no external-resolution switch; proves the proxy preserves native PSResourceGet behaviorusing module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Install-PSResource native route' {

    It 'invokes the native Install-PSResource command without external dependency resolution' {
        {
            Install-PSResource `
                -Name 'Amiasea.Test' `
                -WhatIf `
                -ErrorAction Stop
        } |
            Should -Not -Throw
    }

    It 'passes SkipDependencyCheck through the native route' {
        {
            Install-PSResource `
                -Name 'Amiasea.Test' `
                -SkipDependencyCheck `
                -WhatIf `
                -ErrorAction Stop
        } |
            Should -Not -Throw
    }
}