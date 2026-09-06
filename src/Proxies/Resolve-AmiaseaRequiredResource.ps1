function Resolve-AmiaseaRequiredResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [object]$Version
    )

    $findParameters = @{
        Name        = $Name
        Repository = 'Amiasea'
        ErrorAction = 'Stop'
    }

    if ($null -ne $Version) {
        $findParameters['Version'] = $Version
    }

    $resource = Find-PSResource @findParameters |
        Select-Object -First 1

    if ($null -eq $resource) {
        throw "Amiasea resource '$Name' could not be found."
    }

    $requiredResource = @{}

    foreach ($dependency in @($resource.Dependencies)) {
        if (-not $dependency.Name) {
            continue
        }

        $dependencySpec = @{
            version = [string]$dependency.Version
        }

        if ($dependency.Repository) {
            $dependencySpec['repository'] = [string]$dependency.Repository
        }

        $requiredResource[[string]$dependency.Name] = $dependencySpec
    }

    return $requiredResource
}