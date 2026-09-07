# -UseExternalDependencyResolution end-to-end behavior; converter → resolver → explicit RequiredResource → native installationusing module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Install-PSResource external dependency resolution' {

    It 'installs an Amiasea resource using external dependency resolution' {
        {
            Install-PSResource `
                -Name 'Amiasea.Workspace' `
                -UseExternalDependencyResolution `
                -Scope CurrentUser `
                -ErrorAction Stop
        } |
            Should -Not -Throw
    }

    It 'installs an explicitly requested Amiasea resource version using external dependency resolution' {
        {
            Install-PSResource `
                -Name 'Amiasea.Workspace' `
                -Version '1.0.43' `
                -UseExternalDependencyResolution `
                -Scope CurrentUser `
                -ErrorAction Stop
        } |
            Should -Not -Throw
    }
}