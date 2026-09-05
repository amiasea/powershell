using module ./Workspace.Types.psm1

. $PSScriptRoot/Workspace.Git.ps1
. $PSScriptRoot/Resolve.Workspace.ps1
. $PSScriptRoot/Build.Workspace.ps1

Export-ModuleMember -Function `
    Resolve-Workspace, `
    Build-Workspace