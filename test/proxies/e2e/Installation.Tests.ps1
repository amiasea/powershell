# Actual installed resources and resulting state; version selection, dependency presence, repeated installation, etc.

using module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Install-PSResource installation' {

    It 'installs the Amiasea resource' {
        Install-PSResource `
            -Name 'Amiasea.Workspace' `
            -UseExternalDependencyResolution `
            -Scope CurrentUser `
            -ErrorAction Stop

        $resource = Get-InstalledPSResource `
            -Name 'Amiasea.Workspace' `
            -Scope CurrentUser `
            -ErrorAction Stop |
            Select-Object -First 1

        $resource |
            Should -Not -BeNullOrEmpty

        $resource.Name |
            Should -Be 'Amiasea.Workspace'
    }

    It 'installs the explicitly requested Amiasea resource version' {
        Install-PSResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.0.43' `
            -UseExternalDependencyResolution `
            -Scope CurrentUser `
            -ErrorAction Stop

        $resource = Get-InstalledPSResource `
            -Name 'Amiasea.Workspace' `
            -Scope CurrentUser `
            -ErrorAction Stop |
            Where-Object Version -eq '1.0.43' |
            Select-Object -First 1

        $resource |
            Should -Not -BeNullOrEmpty

        $resource.Name |
            Should -Be 'Amiasea.Workspace'

        $resource.Version |
            Should -Be '1.0.43'
    }

    It 'installs the external dependency' {
        Install-PSResource `
            -Name 'Amiasea.Workspace' `
            -UseExternalDependencyResolution `
            -Scope CurrentUser `
            -ErrorAction Stop

        $resource = Get-InstalledPSResource `
            -Name 'PowerShellForGitHub' `
            -Scope CurrentUser `
            -ErrorAction Stop |
            Select-Object -First 1

        $resource |
            Should -Not -BeNullOrEmpty

        $resource.Name |
            Should -Be 'PowerShellForGitHub'
    }
}