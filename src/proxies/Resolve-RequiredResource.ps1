function Resolve-RequiredResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [object]$Version,

        [Parameter()]
        [AllowNull()]
        [string]$Repository
    )

    Write-Host '=== RESOLVE RESOURCE ==='
    Write-Host "Name: [$Name]"
    Write-Host "Version supplied: [$($null -ne $Version)]"
    Write-Host "Version: [$Version]"
    Write-Host "Repository supplied: [$(-not [string]::IsNullOrEmpty($Repository))]"
    Write-Host "Repository: [$Repository]"

    $findParameters = @{
        Name        = $Name
        ErrorAction = 'Stop'
    }

    if ($null -ne $Version) {
        $findParameters['Version'] = $Version
    }

    if (-not [string]::IsNullOrEmpty($Repository)) {
        $findParameters['Repository'] = $Repository
    }

    Write-Host 'Find-PSResource parameters:'
    foreach ($key in $findParameters.Keys) {
        Write-Host "  $key = [$($findParameters[$key])]"
    }

    $resource = Find-PSResource @findParameters |
        Select-Object -First 1

    if ($null -eq $resource) {
        throw "Resource '$Name' could not be found."
    }

    Write-Host 'Resolved resource:'
    Write-Host "  Name: [$($resource.Name)]"
    Write-Host "  Version: [$($resource.Version)]"
    Write-Host "  Prerelease: [$($resource.Prerelease)]"
    Write-Host "  Repository: [$($resource.Repository)]"

    #
    # The lookup result must actually represent the resource requested by the
    # caller. The resolver does not silently accept metadata for another
    # resource.
    #
    if ([string]$resource.Name -ne $Name) {
        throw "Resolver invariant violated: requested '$Name', but Find-PSResource returned '$($resource.Name)'."
    }

    #
    # An explicitly supplied version is an exact lookup constraint for the
    # root resource. Do not accept a different version as satisfying it.
    #
    if ($null -ne $Version) {
        if ([string]$resource.Version -ne [string]$Version) {
            throw "Resolver invariant violated: requested version '$Version', but Find-PSResource returned '$($resource.Version)'."
        }
    }

    #
    # Repository identity is required for the resolved root because the
    # resolver's output ultimately represents repository-qualified resources.
    #
    if (-not $resource.Repository) {
        throw "Resolver invariant violated: resource '$Name' resolved without a repository."
    }

    $requiredResource = @{}

    #
    # Only the root resource's immediate declared dependencies belong to this
    # resolver's graph boundary. Dependency-of-dependency traversal is
    # intentionally left to the package/dependency system that consumes the
    # resulting installation request.
    #
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

        #
        # A dependency without a name cannot identify an installable resource.
        # Ignore malformed unnamed dependency metadata rather than inventing a
        # key or attempting to infer its identity.
        #
        if (-not $dependency.Name) {
            Write-Host 'Skipping dependency with no name.'
            continue
        }

        #
        # Once a dependency has an identity, its declared version requirement
        # is mandatory. The resolver preserves this requirement rather than
        # inventing an unconstrained version.
        #
        if (-not $dependency.VersionRange) {
            throw "Resolver invariant violated: dependency '$($dependency.Name)' has no VersionRange."
        }

        $dependencyVersion = [string]$dependency.VersionRange

        Write-Host "Dependency version specification: [$dependencyVersion]"

        #
        # An explicitly declared repository is authoritative dependency
        # metadata. Preserve it directly rather than performing another lookup
        # that could select a different repository.
        #
        if ($dependency.Repository) {
            $dependencyRepository = [string]$dependency.Repository
        }
        else {
            #
            # When repository identity is absent from dependency metadata,
            # establish it through normal Find-PSResource resolution. The
            # declared version range is used for the lookup, but the original
            # range remains the version requirement in the output.
            #
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

            #
            # The lookup must establish repository provenance. A resource
            # without repository identity cannot become an explicit
            # RequiredResource entry.
            #
            if (-not $dependencyResource.Repository) {
                throw "Resolver invariant violated: dependency '$($dependency.Name)' resolved without a repository."
            }

            $dependencyRepository = [string]$dependencyResource.Repository
        }

        if (-not $dependencyRepository) {
            throw "Resolver invariant violated: dependency '$($dependency.Name)' has no repository."
        }

        #
        # Preserve the dependency's declared version range exactly. The
        # concrete version returned by Find-PSResource is used only to discover
        # repository identity when the declaration omitted one.
        #
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