using module ../../../.build/proxies/out/Amiasea.Proxies.psd1

BeforeAll {
    $modulePath = Join-Path `
        $PSScriptRoot `
        '../../../.build/proxies/out/Amiasea.Proxies.psd1'

    Import-Module $modulePath -Force
}

Describe 'Repository resolution' {

    It 'resolves the Amiasea root resource from the Amiasea repository' {
        $resource = Find-PSResource `
            -Name 'Amiasea.Workspace' `
            -Repository 'Amiasea' `
            -ErrorAction Stop |
            Select-Object -First 1

        $resource |
            Should -Not -BeNullOrEmpty

        $resource.Name |
            Should -Be 'Amiasea.Workspace'

        $resource.Repository |
            Should -Be 'Amiasea'
    }

    It 'resolves the external dependency from PSGallery' {
        $resource = Find-PSResource `
            -Name 'PowerShellForGitHub' `
            -Repository 'PSGallery' `
            -ErrorAction Stop |
            Select-Object -First 1

        $resource |
            Should -Not -BeNullOrEmpty

        $resource.Name |
            Should -Be 'PowerShellForGitHub'

        $resource.Repository |
            Should -Be 'PSGallery'
    }
}