$command = Get-Command `
    -Name Install-PSResource `
    -CommandType Cmdlet `
    -ErrorAction Stop

$proxy = [System.Management.Automation.ProxyCommand]::Create(
    $command
)

$injectedProcess = @'
process {
    $amiaseaNames = @(
        if ($PSBoundParameters.ContainsKey('Name')) {
            @($PSBoundParameters['Name']) |
                Where-Object {
                    $_ -is [string] -and
                    $_ -match '^Amiasea\.'
                }
        }
    )

    if (
        $amiaseaNames.Count -gt 0 -and
        -not $PSBoundParameters.ContainsKey('RequiredResource') -and
        -not $PSBoundParameters.ContainsKey('RequiredResourceFile')
    ) {
        if ($amiaseaNames.Count -ne 1) {
            throw "Install-PSResource proxy currently supports exactly one Amiasea resource per invocation."
        }

        $amiaseaName = [string]$amiaseaNames[0]

        #
        # Resolve the Amiasea resource using the same version and prerelease
        # constraints supplied to Install-PSResource, if any.
        #
        $findParameters = @{
            Name        = $amiaseaName
            Repository  = 'Amiasea'
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters.ContainsKey('Version')) {
            $findParameters['Version'] = $PSBoundParameters['Version']
        }

        if ($PSBoundParameters.ContainsKey('Prerelease')) {
            $findParameters['Prerelease'] = $PSBoundParameters['Prerelease']
        }

        $resource = Find-PSResource @findParameters |
            Select-Object -First 1

        if ($null -eq $resource) {
            throw "Amiasea resource '$amiaseaName' could not be found."
        }

        #
        # Make the selected version explicit.
        #
        $selectedVersion = [string]$resource.Version

        if ($resource.Prerelease) {
            $selectedVersion += "-$($resource.Prerelease)"
        }

        $PSBoundParameters['Version'] = $selectedVersion

        #
        # Resolve the dependency metadata for the selected Amiasea resource.
        #
        # Resolve-AmiaseaRequiredResource is intentionally internal to the
        # proxy. There is no public Get-AmiaseaRequiredResources command.
        #
        $amiaseaRequiredResource = Resolve-AmiaseaRequiredResource `
            -Name $amiaseaName `
            -Version $selectedVersion

        #
        # RequiredResource is a separate native parameter set, so replace
        # Name/Version with the equivalent native RequiredResource entry.
        #
        $PSBoundParameters.Remove('Name')

        $PSBoundParameters['RequiredResource'] = @{
            $amiaseaName = @{
                version    = $selectedVersion
                repository = 'Amiasea'
            }
        }

        foreach ($dependencyName in $amiaseaRequiredResource.Keys) {
            $PSBoundParameters['RequiredResource'][$dependencyName] =
                $amiaseaRequiredResource[$dependencyName]
        }

        $PSBoundParameters.Remove('Version')
    }

    & $scriptCmd @PSBoundParameters
}
'@

$processPattern = '(?s)process\s*\{.*?\n\}'

if ($proxy -notmatch $processPattern) {
    throw "Unable to locate generated Install-PSResource process block."
}

$proxy = [regex]::Replace(
    $proxy,
    $processPattern,
    $injectedProcess,
    1
)

. ([scriptblock]::Create($proxy))