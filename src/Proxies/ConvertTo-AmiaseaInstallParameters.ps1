function ConvertTo-AmiaseaInstallParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters
    )

    if (
        -not $BoundParameters.ContainsKey('Name') -or
        $null -eq $BoundParameters['Name']
    ) {
        return $null
    }

    $names = $BoundParameters['Name']

    if ($names -is [string]) {
        $amiaseaNames = @($names)
    }
    else {
        $amiaseaNames = @($names) |
            Where-Object {
                $_ -is [string] -and
                $_ -match '^Amiasea\.'
            }
    }

    if ($amiaseaNames.Count -eq 0) {
        return $null
    }

    if ($amiaseaNames.Count -ne 1) {
        throw 'Install-PSResource proxy currently supports exactly one Amiasea resource per invocation.'
    }

    $amiaseaName = [string]$amiaseaNames[0]

    Write-Host "DEBUG Name type: $($BoundParameters['Name'].GetType().FullName)"
    Write-Host "DEBUG Name value: <$($BoundParameters['Name'])>"

    $findParameters = @{
        Name        = $amiaseaName
        Repository  = 'Amiasea'
        ErrorAction = 'Stop'
    }

    if ($BoundParameters.ContainsKey('Version')) {
        $findParameters['Version'] = $BoundParameters['Version']
    }

    if ($BoundParameters.ContainsKey('Prerelease')) {
        $findParameters['Prerelease'] = $BoundParameters['Prerelease']
    }

    $resource = Find-PSResource @findParameters |
        Select-Object -First 1

    if ($null -eq $resource) {
        throw "Amiasea resource '$amiaseaName' could not be found."
    }

    $selectedVersion = [string]$resource.Version

    if ($resource.Prerelease) {
        $selectedVersion += "-$($resource.Prerelease)"
    }

    $requiredResource = Resolve-AmiaseaRequiredResource `
        -Name $amiaseaName `
        -Version $selectedVersion

    $result = @{}

    foreach ($key in $BoundParameters.Keys) {
        $result[$key] = $BoundParameters[$key]
    }

    $result.Remove('Name')
    $result.Remove('Version')

    $result['RequiredResource'] = @{
        $amiaseaName = @{
            version    = $selectedVersion
            repository = 'Amiasea'
        }
    }

    foreach ($dependencyName in $requiredResource.Keys) {
        $result['RequiredResource'][$dependencyName] =
            $requiredResource[$dependencyName]
    }

    return ,$result
}