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

    $names = if ($BoundParameters['Name'] -is [string]) {
        @($BoundParameters['Name'])
    }
    else {
        @($BoundParameters['Name'])
    }

    $amiaseaNames = @(
        $names | Where-Object {
            $_ -is [string] -and
            $_ -match '^Amiasea\.'
        }
    )

    if ($amiaseaNames.Count -eq 0) {
        return $null
    }

    if ($amiaseaNames.Count -ne 1) {
        throw 'Install-PSResource proxy currently supports exactly one Amiasea resource per invocation.'
    }

    $amiaseaName = [string]$amiaseaNames[0]

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