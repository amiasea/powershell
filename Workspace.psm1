. $PSScriptRoot/scripts/Workspace.Resolve.ps1
. $PSScriptRoot/scripts/Workspace.Build.ps1

Export-ModuleMember -Function `
    Resolve-Workspace, `
    Build-Workspace