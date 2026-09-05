function Invoke-WorkspaceGitClone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $cloneOptions = [LibGit2Sharp.CloneOptions]::new()
    $cloneOptions.Checkout = $false

    [LibGit2Sharp.Repository]::Clone(
        $Url,
        $Path,
        $cloneOptions
    )
}