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

    $names = @($BoundParameters['Name'])

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

    $selectedVersion = $null

    if (
        $BoundParameters.ContainsKey('Version') -and
        $null -ne $BoundParameters['Version']
    ) {
        $selectedVersion = [string]$BoundParameters['Version']
    }
    else {
        $findParameters = @{
            Name        = $amiaseaName
            Repository  = 'Amiasea'
            ErrorAction = 'Stop'
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
    $result.Remove('Repository')

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