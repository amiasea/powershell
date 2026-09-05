. $PSScriptRoot/Workspace.Types.ps1
. $PSScriptRoot/Resolve.Workspace.ps1
. $PSScriptRoot/Build.Workspace.ps1

Export-ModuleMember -Function `
    Resolve-Workspace, `
    Build-Workspace