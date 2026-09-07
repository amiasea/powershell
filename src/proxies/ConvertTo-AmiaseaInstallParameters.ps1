function ConvertTo-AmiaseaInstallParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters
    )

    Write-Host '=== AMIASEA CONVERTER ==='

    Write-Host "Name: [$($BoundParameters['Name'])]"
    Write-Host "Has Version: $($BoundParameters.ContainsKey('Version'))"
    Write-Host "Version: [$($BoundParameters['Version'])]"
    Write-Host "Has Repository: $($BoundParameters.ContainsKey('Repository'))"
    Write-Host "Repository: [$($BoundParameters['Repository'])]"
    Write-Host "Has Prerelease: $($BoundParameters.ContainsKey('Prerelease'))"
    Write-Host "Prerelease: [$($BoundParameters['Prerelease'])]"

    #
    # Explicit RequiredResource and RequiredResourceFile requests are already
    # expressed in the native installation model. The Amiasea converter only
    # transforms direct Amiasea resource requests.
    #
    if (
        $BoundParameters.ContainsKey('RequiredResource') -or
        $BoundParameters.ContainsKey('RequiredResourceFile')
    ) {
        return $null
    }

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

    #
    # Non-Amiasea resources remain entirely under native PSResourceGet
    # semantics. This converter must not intercept them.
    #
    if ($amiaseaNames.Count -eq 0) {
        return $null
    }

    if ($amiaseaNames.Count -ne 1) {
        throw 'Install-PSResource proxy currently supports exactly one Amiasea resource per invocation.'
    }

    $amiaseaName = [string]$amiaseaNames[0]

    $selectedVersion = $null

    #
    # An explicitly supplied version is already authoritative for the root
    # request, so there is no need to perform a second root lookup merely to
    # discover the same version.
    #
    if (
        $BoundParameters.ContainsKey('Version') -and
        $null -ne $BoundParameters['Version']
    ) {
        Write-Host 'Version supplied explicitly; skipping Find-PSResource for root resource.'

        $selectedVersion = [string]$BoundParameters['Version']
    }
    else {
        #
        # Amiasea resource discovery is intentionally Amiasea-specific. The
        # converter establishes the root resource from the Amiasea repository;
        # the generic dependency resolver is responsible only for resolving
        # the root's declared dependencies.
        #
        Write-Host 'No version supplied; resolving root resource with Find-PSResource.'

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

        Write-Host 'Resolved root resource:'
        Write-Host "  Name: [$($resource.Name)]"
        Write-Host "  Version: [$($resource.Version)]"
        Write-Host "  Prerelease: [$($resource.Prerelease)]"
        Write-Host "  Repository: [$($resource.Repository)]"

        $selectedVersion = [string]$resource.Version

        Write-Host "Selected version: [$selectedVersion]"

        if ($resource.Prerelease) {
            $selectedVersion += "-$($resource.Prerelease)"
        }
    }

    #
    # Dependency resolution itself is delegated to the generic resolver. The
    # converter supplies the Amiasea root identity and selected version but
    # does not implement dependency traversal itself.
    #
    Write-Host 'Calling Resolve-RequiredResource:'
    Write-Host "  Name: [$amiaseaName]"
    Write-Host "  Version: [$selectedVersion]"

    $requiredResource = Resolve-RequiredResource `
        -Name $amiaseaName `
        -Version $selectedVersion

    Write-Host 'Resolved dependencies:'

    foreach ($dependencyName in $requiredResource.Keys) {
        $dependency = $requiredResource[$dependencyName]

        Write-Host "  $dependencyName"
        Write-Host "    version: [$($dependency['version'])]"
        Write-Host "    repository: [$($dependency['repository'])]"
    }

    #
    # Preserve all native parameters except the direct resource-selection
    # parameters that have now been represented by RequiredResource.
    #
    $result = @{}

    foreach ($key in $BoundParameters.Keys) {
        $result[$key] = $BoundParameters[$key]
    }

    $result.Remove('Name')
    $result.Remove('Version')
    $result.Remove('Repository')

    #
    # The Amiasea root is always explicitly represented as an Amiasea
    # repository requirement. A caller-supplied Repository does not change
    # that identity because this converter exists specifically to translate
    # Amiasea resource requests.
    #
    $result['RequiredResource'] = @{
        $amiaseaName = @{
            version    = $selectedVersion
            repository = 'Amiasea'
        }
    }

    #
    # Add the generic resolver's immediate dependency requirements without
    # changing their declared version ranges or repository identities.
    #
    foreach ($dependencyName in $requiredResource.Keys) {
        $result['RequiredResource'][$dependencyName] =
            $requiredResource[$dependencyName]
    }

    Write-Host 'Final RequiredResource:'

    foreach ($name in $result['RequiredResource'].Keys) {
        $spec = $result['RequiredResource'][$name]

        Write-Host "  $name"
        Write-Host "    version: [$($spec['version'])]"
        Write-Host "    repository: [$($spec['repository'])]"
    }

    Write-Host 'Top-level parameters remaining:'

    foreach ($key in $result.Keys) {
        Write-Host "  $key"
    }

    #
    # These parameters have been consumed into RequiredResource and must not
    # remain at the top level where they could cause native PSResourceGet to
    # perform a second, conflicting root selection.
    #
    if ($result.ContainsKey('Name')) {
        throw 'Amiasea converter invariant violated: Name remains in transformed parameters.'
    }

    if ($result.ContainsKey('Version')) {
        throw 'Amiasea converter invariant violated: Version remains in transformed parameters.'
    }

    if ($result.ContainsKey('Repository')) {
        throw 'Amiasea converter invariant violated: Repository remains in transformed parameters.'
    }

    if (-not $result.ContainsKey('RequiredResource')) {
        throw 'Amiasea converter invariant violated: RequiredResource was not produced.'
    }

    if (-not $result['RequiredResource'].ContainsKey($amiaseaName)) {
        throw "Amiasea converter invariant violated: root resource '$amiaseaName' is missing."
    }

    $rootSpec = $result['RequiredResource'][$amiaseaName]

    if ($rootSpec['version'] -ne $selectedVersion) {
        throw "Amiasea converter invariant violated: root version '$($rootSpec['version'])' does not equal selected version '$selectedVersion'."
    }

    if ($rootSpec['repository'] -ne 'Amiasea') {
        throw "Amiasea converter invariant violated: root repository is '$($rootSpec['repository'])'."
    }

    Write-Host '=== END AMIASEA CONVERTER ==='

    return ,$result
}