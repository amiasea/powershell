function Resolve-AmiaseaRequiredResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [object]$Version
    )

    Write-Host '=== RESOLVE AMIASEA RESOURCE ==='
    Write-Host "Name: [$Name]"
    Write-Host "Version supplied: [$($null -ne $Version)]"
    Write-Host "Version: [$Version]"

    $findParameters = @{
        Name        = $Name
        Repository  = 'Amiasea'
        ErrorAction = 'Stop'
    }

    if ($null -ne $Version) {
        $findParameters['Version'] = $Version
    }

    Write-Host 'Find-PSResource parameters:'
    foreach ($key in $findParameters.Keys) {
        Write-Host "  $key = [$($findParameters[$key])]"
    }

    $resource = Find-PSResource @findParameters |
        Select-Object -First 1

    if ($null -eq $resource) {
        throw "Amiasea resource '$Name' could not be found."
    }

    Write-Host 'Resolved resource:'
    Write-Host "  Name: [$($resource.Name)]"
    Write-Host "  Version: [$($resource.Version)]"
    Write-Host "  Prerelease: [$($resource.Prerelease)]"
    Write-Host "  Repository: [$($resource.Repository)]"

    if ([string]$resource.Name -ne $Name) {
        throw "Resolver invariant violated: requested '$Name', but Find-PSResource returned '$($resource.Name)'."
    }

    if ($null -ne $Version) {
        if ([string]$resource.Version -ne [string]$Version) {
            throw "Resolver invariant violated: requested version '$Version', but Find-PSResource returned '$($resource.Version)'."
        }
    }

    $requiredResource = @{}

    $dependencies = @($resource.Dependencies)

    Write-Host "Dependency count: $($dependencies.Count)"

    foreach ($dependency in $dependencies) {
        Write-Host '--- DEPENDENCY ---'
        Write-Host "Name: [$($dependency.Name)]"
        Write-Host "VersionRange: [$($dependency.VersionRange)]"

        if ($null -eq $dependency.VersionRange) {
            Write-Host 'VersionRange is NULL.'
        }
        else {
            Write-Host "VersionRange type: [$($dependency.VersionRange.GetType().FullName)]"
            Write-Host "VersionRange string: [$([string]$dependency.VersionRange)]"
        }

        Write-Host "Repository: [$($dependency.Repository)]"
        Write-Host "Dependency type: [$($dependency.GetType().FullName)]"

        if (-not $dependency.Name) {
            Write-Host 'Skipping dependency with no name.'
            continue
        }

        if (-not $dependency.VersionRange) {
            throw "Resolver invariant violated: dependency '$($dependency.Name)' has no VersionRange."
        }

        $dependencyVersion = [string]$dependency.VersionRange

        Write-Host "Dependency version specification: [$dependencyVersion]"

        if ($dependency.Repository) {
            $dependencyRepository = [string]$dependency.Repository
        }
        else {
            Write-Host "Dependency repository not specified; resolving repository for [$($dependency.Name)]."

            $dependencyFindParameters = @{
                Name        = [string]$dependency.Name
                Version     = $dependencyVersion
                ErrorAction = 'Stop'
            }

            $dependencyResource = Find-PSResource @dependencyFindParameters |
                Select-Object -First 1

            if ($null -eq $dependencyResource) {
                throw "Dependency '$($dependency.Name)' with version '$dependencyVersion' could not be found in any registered repository."
            }

            Write-Host 'Resolved dependency resource:'
            Write-Host "  Name: [$($dependencyResource.Name)]"
            Write-Host "  Version: [$($dependencyResource.Version)]"
            Write-Host "  Repository: [$($dependencyResource.Repository)]"

            if (-not $dependencyResource.Repository) {
                throw "Resolver invariant violated: dependency '$($dependency.Name)' resolved without a repository."
            }

            $dependencyRepository = [string]$dependencyResource.Repository
        }

        if (-not $dependencyRepository) {
            throw "Resolver invariant violated: dependency '$($dependency.Name)' has no repository."
        }

        $dependencySpec = @{
            version    = $dependencyVersion
            repository = $dependencyRepository
        }

        Write-Host 'RequiredResource entry:'
        foreach ($key in $dependencySpec.Keys) {
            Write-Host "  $key = [$($dependencySpec[$key])]"
        }

        $requiredResource[[string]$dependency.Name] = $dependencySpec

        Write-Host '--- END DEPENDENCY ---'
    }

    Write-Host '=== RESOLVER OUTPUT ==='

    if ($requiredResource.Count -eq 0) {
        Write-Host 'RequiredResource is empty.'
    }
    else {
        foreach ($dependencyName in $requiredResource.Keys) {
            $dependencySpec = $requiredResource[$dependencyName]

            Write-Host "  $dependencyName"

            foreach ($key in $dependencySpec.Keys) {
                Write-Host "    $key = [$($dependencySpec[$key])]"
            }
        }
    }

    Write-Host '=== END RESOLVER ==='

    return ,$requiredResource
}