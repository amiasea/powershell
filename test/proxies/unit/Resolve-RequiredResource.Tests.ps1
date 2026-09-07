BeforeAll {
    . (Join-Path $PSScriptRoot '../../../src/proxies/Resolve-RequiredResource.ps1')
}

Describe 'Resolve-RequiredResource' {

    It 'resolves the immediate dependencies declared by the requested resource' {
        #
        # The resolver establishes the dependency requirements of the resource
        # being resolved. It does not need to understand why the resource has
        # a particular name or where that resource belongs organizationally.
        #
        # These fixtures deliberately use resources from different repositories
        # to ensure repository identity is treated as dependency metadata rather
        # than as a property inferred from the resource name.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Amiasea.Workspace'
                Version      = '1.2.3'
                Prerelease   = $false
                Repository   = 'Amiasea'
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'PowerShellForGitHub'
                        VersionRange = '[0.17.0,0.18.0)'
                        Repository   = 'PSGallery'
                    }
                    [pscustomobject]@{
                        Name         = 'Amiasea.Shared'
                        VersionRange = '[2.0.0,3.0.0)'
                        Repository   = 'Amiasea'
                    }
                )
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Amiasea.Workspace' `
            -Version '1.2.3' `
            -Repository 'Amiasea'

        $result.Keys |
            Should -HaveCount 2

        $result.Keys |
            Should -Contain 'PowerShellForGitHub'

        $result.Keys |
            Should -Contain 'Amiasea.Shared'

        $result['PowerShellForGitHub'].version |
            Should -Be '[0.17.0,0.18.0)'

        $result['PowerShellForGitHub'].repository |
            Should -Be 'PSGallery'

        $result['Amiasea.Shared'].version |
            Should -Be '[2.0.0,3.0.0)'

        $result['Amiasea.Shared'].repository |
            Should -Be 'Amiasea'
    }

    It 'passes the requested name to Find-PSResource' {
        #
        # The resolver should ask PSResourceGet to resolve exactly the resource
        # the caller requested. It should not rewrite names or derive repository
        # selection from a namespace embedded in the name.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.2.3'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.2.3'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Module' -and
                $Version -eq '1.2.3' -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'passes an explicitly supplied repository to Find-PSResource' {
        #
        # Repository is an optional constraint supplied by the caller. When it
        # exists, the resolver must preserve it as part of the lookup rather
        # than silently replacing it with a resolver-specific repository.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.2.3'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.2.3' `
            -Repository 'ExampleRepository'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Module' -and
                $Version -eq '1.2.3' -and
                $Repository -eq 'ExampleRepository' -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'does not supply a repository constraint when the caller did not specify one' {
        #
        # Repository selection belongs to Find-PSResource when the caller does
        # not constrain it. The generic resolver must not invent a repository
        # based on the resource name, namespace, or any other application-
        # specific convention.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.2.3'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.2.3'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Module' -and
                $Version -eq '1.2.3' -and
                $null -eq $Repository -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'allows the root version to be omitted' {
        #
        # Version is a lookup constraint, not an intrinsic requirement of the
        # resolver API. When omitted, Find-PSResource is responsible for
        # selecting the appropriate resource version according to its normal
        # resolution semantics.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '2.4.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module'

        $result |
            Should -BeNullOrEmpty

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Module' -and
                $null -eq $Version -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'preserves the declared version range of each dependency' {
        #
        # The resolver is not responsible for converting dependency version
        # ranges into a concrete version. The declared range is the requirement
        # that must be carried into RequiredResource.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'Example.Dependency'
                        VersionRange = '[3.2.0,4.0.0)'
                        Repository   = 'DependencyRepository'
                    }
                )
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result['Example.Dependency'].version |
            Should -Be '[3.2.0,4.0.0)'
    }

    It 'preserves an explicitly declared dependency repository' {
        #
        # Once dependency metadata explicitly identifies a repository, that
        # declaration should be preserved. Performing another unrestricted
        # lookup could select a different repository and would therefore change
        # the meaning of the dependency declaration.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'Example.Dependency'
                        VersionRange = '[3.2.0,4.0.0)'
                        Repository   = 'DependencyRepository'
                    }
                )
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result['Example.Dependency'].repository |
            Should -Be 'DependencyRepository'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly
    }

    It 'resolves the repository of a dependency when the dependency declaration does not specify one' {
        #
        # Dependency metadata is allowed to omit repository identity. In that
        # case, the resolver must establish the repository by asking
        # Find-PSResource to resolve the dependency using its declared version
        # range and normal repository-selection behavior.
        #
        Mock Find-PSResource {
            param(
                [string]$Name,
                [object]$Version,
                [string]$Repository
            )

            if ($Name -eq 'Example.Module') {
                return [pscustomobject]@{
                    Name         = 'Example.Module'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = 'ExampleRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Example.Dependency'
                            VersionRange = '[3.2.0,4.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            if ($Name -eq 'Example.Dependency') {
                return [pscustomobject]@{
                    Name         = 'Example.Dependency'
                    Version      = '3.4.0'
                    Prerelease   = $false
                    Repository   = 'DependencyRepository'
                    Dependencies = @()
                }
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result['Example.Dependency'].version |
            Should -Be '[3.2.0,4.0.0)'

        $result['Example.Dependency'].repository |
            Should -Be 'DependencyRepository'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Dependency' -and
                $Version -eq '[3.2.0,4.0.0)' -and
                $null -eq $Repository -and
                $ErrorAction -eq 'Stop'
            }
    }

    It 'does not resolve a dependency again when its repository is already declared' {
        #
        # An explicit dependency repository is sufficient to construct the
        # RequiredResource entry. There is no reason to perform another lookup,
        # and doing so could introduce repository or version-selection behavior
        # that contradicts the dependency declaration.
        #
        Mock Find-PSResource {
            param(
                [string]$Name
            )

            if ($Name -eq 'Example.Module') {
                return [pscustomobject]@{
                    Name         = 'Example.Module'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = 'ExampleRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Example.Dependency'
                            VersionRange = '[3.2.0,4.0.0)'
                            Repository   = 'DependencyRepository'
                        }
                    )
                }
            }

            throw "Unexpected lookup for '$Name'."
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result['Example.Dependency'].repository |
            Should -Be 'DependencyRepository'

        Should -Invoke Find-PSResource `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Module'
            }

        Should -Invoke Find-PSResource `
            -Times 0 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Dependency'
            }
    }

    It 'rejects a missing root resource' {
        #
        # A missing root resource means there is no authoritative dependency
        # metadata to resolve. The failure should describe the requested
        # resource generically rather than assuming anything about its source.
        #
        Mock Find-PSResource {
            $null
        }

        {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'
        } | Should -Throw `
            "Resource 'Example.Module' could not be found."
    }

    It 'rejects a root resource whose returned name does not match the request' {
        #
        # The resolver establishes an invariant between the lookup request and
        # the resource it accepts as the result. It must not silently continue
        # with metadata belonging to a different resource.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Different.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'
        } | Should -Throw `
            "Resolver invariant violated: requested 'Example.Module', but Find-PSResource returned 'Different.Module'."
    }

    It 'rejects a root resource whose returned version does not match an explicit version request' {
        #
        # When the caller explicitly requests a version, the resolver must not
        # claim that a different version satisfied that request.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '2.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'
        } | Should -Throw `
            "Resolver invariant violated: requested version '1.0.0', but Find-PSResource returned '2.0.0'."
    }

    It 'requires the resolved root resource to have repository identity' {
        #
        # Repository identity is part of the resolved resource's provenance.
        # The resolver ultimately produces explicit repository-qualified
        # requirements, so accepting a root resource with no repository would
        # leave the resolution result ambiguous.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = $null
                Dependencies = @()
            }
        }

        {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'
        } | Should -Throw `
            "Resolver invariant violated: resource 'Example.Module' resolved without a repository."
    }

    It 'does not include a dependency without a name' {
        #
        # A dependency without a name cannot identify an installable resource.
        # The resolver should therefore ignore the malformed dependency rather
        # than manufacture a key or attempt to infer one from incomplete metadata.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = $null
                        VersionRange = '[1.0.0,2.0.0)'
                        Repository   = 'DependencyRepository'
                    }
                )
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result |
            Should -BeNullOrEmpty
    }

    It 'rejects a dependency without a VersionRange' {
        #
        # The resolver must preserve the dependency's declared version
        # requirement. If no version requirement exists, it cannot construct a
        # meaningful explicit RequiredResource entry without inventing policy.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @(
                    [pscustomobject]@{
                        Name         = 'Example.Dependency'
                        VersionRange = $null
                        Repository   = 'DependencyRepository'
                    }
                )
            }
        }

        {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'
        } | Should -Throw `
            "Resolver invariant violated: dependency 'Example.Dependency' has no VersionRange."
    }

    It 'rejects a dependency that cannot be resolved when its repository is unspecified' {
        #
        # An unspecified dependency repository means the resolver must consult
        # the normal resource-resolution mechanism. If that mechanism cannot
        # find the dependency, the resolver cannot establish repository
        # identity and therefore cannot produce an explicit requirement.
        #
        Mock Find-PSResource {
            param(
                [string]$Name
            )

            if ($Name -eq 'Example.Module') {
                return [pscustomobject]@{
                    Name         = 'Example.Module'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = 'ExampleRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Unknown.Dependency'
                            VersionRange = '[1.0.0,2.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            $null
        }

        try {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'

            throw 'Expected Resolve-RequiredResource to throw.'
        }
        catch {
            $_.Exception.Message |
                Should -Be "Dependency 'Unknown.Dependency' with version '[1.0.0,2.0.0)' could not be found in any registered repository."
        }
    }

    It 'rejects a dependency lookup result that has no repository identity' {
        #
        # Finding a dependency is not sufficient by itself. The resolver's
        # output must identify where the dependency is to be obtained from.
        # A lookup result without repository provenance therefore violates the
        # resolver's output contract.
        #
        Mock Find-PSResource {
            param(
                [string]$Name
            )

            if ($Name -eq 'Example.Module') {
                return [pscustomobject]@{
                    Name         = 'Example.Module'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = 'ExampleRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Unknown.Dependency'
                            VersionRange = '[1.0.0,2.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            if ($Name -eq 'Unknown.Dependency') {
                return [pscustomobject]@{
                    Name         = 'Unknown.Dependency'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = $null
                    Dependencies = @()
                }
            }
        }

        {
            Resolve-RequiredResource `
                -Name 'Example.Module' `
                -Version '1.0.0'
        } | Should -Throw `
            "Resolver invariant violated: dependency 'Unknown.Dependency' resolved without a repository."
    }

    It 'does not recursively resolve dependencies of dependencies' {
        #
        # This is an intentional boundary of the resolver.
        #
        # We resolve the resource requested by the caller and inspect the
        # dependencies that resource explicitly declares. We do not recursively
        # walk the dependency graph because we cannot assume how a dependency
        # packages its own dependencies. A dependency may bundle them, declare
        # them externally, or represent them through some other mechanism.
        #
        # The dependency's own dependency semantics therefore remain outside
        # this resolver's responsibility.
        #
        Mock Find-PSResource {
            param(
                [string]$Name,
                [object]$Version,
                [string]$Repository
            )

            if ($Name -eq 'Example.Module') {
                return [pscustomobject]@{
                    Name         = 'Example.Module'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = 'ExampleRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Example.Dependency'
                            VersionRange = '[3.0.0,4.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            if ($Name -eq 'Example.Dependency') {
                return [pscustomobject]@{
                    Name         = 'Example.Dependency'
                    Version      = '3.2.0'
                    Prerelease   = $false
                    Repository   = 'DependencyRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Example.Grandchild'
                            VersionRange = '[5.0.0,6.0.0)'
                            Repository   = 'GrandchildRepository'
                        }
                    )
                }
            }

            throw "Unexpected recursive lookup for '$Name'."
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result.Keys |
            Should -HaveCount 1

        $result.Keys |
            Should -Contain 'Example.Dependency'

        $result.Keys |
            Should -Not -Contain 'Example.Grandchild'

        Should -Invoke Find-PSResource `
            -Times 2 `
            -Exactly

        Should -Invoke Find-PSResource `
            -Times 0 `
            -Exactly `
            -ParameterFilter {
                $Name -eq 'Example.Grandchild'
            }
    }

    It 'returns no dependencies when the resolved resource declares none' {
        #
        # An empty dependency set is a valid resolution result. The resolver
        # should not manufacture entries merely because the root resource
        # itself was successfully resolved.
        #
        Mock Find-PSResource {
            [pscustomobject]@{
                Name         = 'Example.Module'
                Version      = '1.0.0'
                Prerelease   = $false
                Repository   = 'ExampleRepository'
                Dependencies = @()
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result |
            Should -BeNullOrEmpty
    }

    It 'does not modify the dependency version requirement while resolving repository identity' {
        #
        # Repository discovery is a separate concern from version-range
        # preservation. Even if Find-PSResource returns a concrete version for
        # the dependency, the RequiredResource contract should retain the
        # original declared range rather than replacing it with that concrete
        # version.
        #
        Mock Find-PSResource {
            param(
                [string]$Name,
                [object]$Version
            )

            if ($Name -eq 'Example.Module') {
                return [pscustomobject]@{
                    Name         = 'Example.Module'
                    Version      = '1.0.0'
                    Prerelease   = $false
                    Repository   = 'ExampleRepository'
                    Dependencies = @(
                        [pscustomobject]@{
                            Name         = 'Example.Dependency'
                            VersionRange = '[3.0.0,4.0.0)'
                            Repository   = $null
                        }
                    )
                }
            }

            if ($Name -eq 'Example.Dependency') {
                return [pscustomobject]@{
                    Name         = 'Example.Dependency'
                    Version      = '3.7.1'
                    Prerelease   = $false
                    Repository   = 'DependencyRepository'
                    Dependencies = @()
                }
            }
        }

        $result = Resolve-RequiredResource `
            -Name 'Example.Module' `
            -Version '1.0.0'

        $result['Example.Dependency'].version |
            Should -Be '[3.0.0,4.0.0)'

        $result['Example.Dependency'].repository |
            Should -Be 'DependencyRepository'
    }
}