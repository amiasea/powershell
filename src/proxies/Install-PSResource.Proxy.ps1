$command = Get-Command `
    -Name Install-PSResource `
    -CommandType Cmdlet `
    -ErrorAction Stop

$proxy = [System.Management.Automation.ProxyCommand]::Create(
    $command
)

$injectedHelp = @'
<#
.SYNOPSIS
    Installs PowerShell resources from registered repositories.

.DESCRIPTION
    Installs PowerShell resources using the native
    Microsoft.PowerShell.PSResourceGet\Install-PSResource command.

    When -UseExternalDependencyResolution is specified, Amiasea resolves
    the dependency graph before installation. The resulting resources are
    converted into explicit RequiredResource entries that include the
    repository from which each resource was resolved.

    This changes the dependency-resolution route; it does not mean that
    the caller must provide an already-resolved dependency graph.

    Without -UseExternalDependencyResolution, dependency resolution is
    performed entirely by PSResourceGet using its normal native behavior.

    With -UseExternalDependencyResolution, Amiasea resolves dependencies
    from the resource's declared dependency metadata and establishes the
    repository identity for each resolved resource. PSResourceGet is then
    used as the installation engine for that explicitly resolved resource
    set rather than independently traversing the dependency graph.

    -RequiredResource and -RequiredResourceFile retain their native
    PSResourceGet meanings. They are not transformed when the external
    dependency-resolution route is not requested.

    -SkipDependencyCheck has its normal native meaning when
    -UseExternalDependencyResolution is not specified: PSResourceGet does
    not check or install dependencies of the resources it finds.

    When -UseExternalDependencyResolution is specified, skipping native
    dependency traversal is required because Amiasea has already performed
    the dependency resolution. Supplying -SkipDependencyCheck explicitly
    is therefore valid and expresses the same native installation
    behavior; it does not disable Amiasea's external dependency
    resolution.

    In other words:

      No switch
        PSResourceGet resolves dependencies and installs resources.

      -SkipDependencyCheck
        PSResourceGet does not resolve or install dependencies.

      -UseExternalDependencyResolution
        Amiasea resolves dependencies, then PSResourceGet installs the
        explicitly resolved resource set without independently resolving
        those dependencies.

      -UseExternalDependencyResolution -SkipDependencyCheck
        Amiasea still resolves dependencies. PSResourceGet is instructed
        to skip its own dependency traversal.

.PARAMETER UseExternalDependencyResolution
    Uses Amiasea's external dependency-resolution route instead of
    PSResourceGet's native dependency-resolution route.

    The switch operates on dependency metadata declared by the resource
    being installed. It does not require the caller to supply a
    pre-resolved dependency graph.

    Amiasea resolves each dependency and establishes the repository from
    which that dependency was resolved. Those resolved resources are then
    represented as explicit RequiredResource entries for the native
    Install-PSResource installation operation.

    This is particularly important when a dependency does not identify a
    repository in its declared dependency metadata. External resolution
    establishes the repository identity before the installation operation
    is passed to PSResourceGet.

    This parameter is owned by the Amiasea proxy and is not passed to the
    underlying Microsoft.PowerShell.PSResourceGet\Install-PSResource
    cmdlet.

    When this switch is used, native dependency traversal is suppressed
    after Amiasea has resolved the dependency set. This prevents
    PSResourceGet from independently resolving the same dependency graph
    and potentially selecting a different repository.

.PARAMETER RequiredResource
    Specifies resources that must be installed.

    This parameter retains its native PSResourceGet meaning.

.PARAMETER RequiredResourceFile
    Specifies a file containing resources that must be installed.

    This parameter retains its native PSResourceGet meaning.

.PARAMETER SkipDependencyCheck
    Prevents PSResourceGet from checking or installing dependencies of
    resources it finds.

    Without -UseExternalDependencyResolution, this has the native
    PSResourceGet behavior: dependency resolution is skipped.

    With -UseExternalDependencyResolution, Amiasea still performs its
    external dependency resolution. The switch only expresses that native
    PSResourceGet dependency traversal should be skipped, which is already
    required by the external-resolution route.

    Therefore these two commands have the same dependency-resolution route:

        Install-PSResource `
            -Name Amiasea.Workspace `
            -UseExternalDependencyResolution

        Install-PSResource `
            -Name Amiasea.Workspace `
            -UseExternalDependencyResolution `
            -SkipDependencyCheck

    The second command does not mean "do not resolve dependencies."
    Amiasea still resolves them.

.EXAMPLE
    Install-PSResource -Name Amiasea.Workspace

    Installs Amiasea.Workspace using the native PSResourceGet
    dependency-resolution route.

.EXAMPLE
    Install-PSResource `
        -Name Amiasea.Workspace `
        -UseExternalDependencyResolution

    Installs Amiasea.Workspace using Amiasea's external dependency
    resolution.

.EXAMPLE
    Install-PSResource `
        -Name Amiasea.Workspace `
        -UseExternalDependencyResolution `
        -SkipDependencyCheck

    Uses Amiasea's external dependency-resolution route while explicitly
    instructing PSResourceGet to skip its native dependency check.

    The explicit -SkipDependencyCheck does not prevent Amiasea from
    resolving dependencies.

.NOTES
    -UseExternalDependencyResolution is an Amiasea proxy parameter.
    It is not a native PSResourceGet parameter and is consumed by the
    proxy before the native Install-PSResource command is invoked.
#>
'@

$injectedBegin = @'
begin
{
    try {
        #
        # Capture the Amiasea-owned switch before transforming the
        # parameters. It must never be forwarded to native PSResourceGet.
        #
        $useExternalDependencyResolution =
            $PSBoundParameters.ContainsKey(
                'UseExternalDependencyResolution'
            )

        if ($useExternalDependencyResolution) {
            [void]$PSBoundParameters.Remove(
                'UseExternalDependencyResolution'
            )

            #
            # External dependency resolution requires a root resource.
            # Name identifies that root; Version and Prerelease constrain
            # the root resolution. Repository is deliberately not used as
            # the native repository selector because the Amiasea root is
            # resolved through the external route.
            #
            $resolutionParameters = @{}

            foreach ($key in @(
                'Name',
                'Version',
                'Prerelease'
            )) {
                if ($PSBoundParameters.ContainsKey($key)) {
                    $resolutionParameters[$key] =
                        $PSBoundParameters[$key]
                }
            }

            if (-not $resolutionParameters.ContainsKey('Name')) {
                throw `
                    '-UseExternalDependencyResolution requires -Name so Amiasea can determine the resource whose dependency graph must be resolved.'
            }

            #
            # Resolve the Amiasea root and its declared dependency graph.
            #
            $externallyResolvedParameters =
                ConvertTo-AmiaseaInstallParameters `
                    -BoundParameters $resolutionParameters

            if ($null -eq $externallyResolvedParameters) {
                throw `
                    'External dependency resolution did not produce an Amiasea installation request.'
            }

            if (-not $externallyResolvedParameters.ContainsKey('RequiredResource')) {
                throw `
                    'External dependency resolution did not produce RequiredResource entries.'
            }

            #
            # Start with the caller's native parameters.
            #
            $nativeParameters = @{}

            foreach ($key in $PSBoundParameters.Keys) {
                #
                # Name, Version, and Repository identify the direct resource
                # request consumed by the external resolver. They must not
                # be forwarded to native PSResourceGet after the request has
                # been converted to RequiredResource.
                #
                if ($key -in @(
                    'Name',
                    'Version',
                    'Repository'
                )) {
                    continue
                }

                $nativeParameters[$key] =
                    $PSBoundParameters[$key]
            }

            #
            # The converter's RequiredResource set is now the explicit
            # installation request passed to native PSResourceGet.
            #
            $nativeParameters['RequiredResource'] =
                $externallyResolvedParameters['RequiredResource']

            #
            # Native dependency traversal must be disabled because the
            # dependency graph has already been resolved externally.
            #
            $nativeParameters['SkipDependencyCheck'] = $true

            #
            # Rebuild PSBoundParameters from the externally resolved
            # installation request.
            #
            $PSBoundParameters.Clear()

            foreach ($key in $nativeParameters.Keys) {
                $PSBoundParameters[$key] =
                    $nativeParameters[$key]
            }
        }

        #
        # When external dependency resolution was not requested, leave
        # PSBoundParameters completely untouched. This is the native
        # PSResourceGet route.
        #
        Write-Host '=== AMIASEA PROXY PARAMETERS ===' -ForegroundColor Cyan

        $PSBoundParameters.GetEnumerator() |
            ForEach-Object {
                Write-Host "$($_.Key) = $($_.Value | Out-String)"
            }

        Write-Host '=== END AMIASEA PROXY PARAMETERS ===' -ForegroundColor Cyan

        $outBuffer = $null

        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(
            'Microsoft.PowerShell.PSResourceGet\Install-PSResource',
            [System.Management.Automation.CommandTypes]::Cmdlet
        )

        $scriptCmd = {
            & $wrappedCmd @PSBoundParameters
        }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline(
            $myInvocation.CommandOrigin
        )

        $steppablePipeline.Begin($PSCmdlet)
    }
    catch {
        throw
    }
}
'@

#
# Parse the generated proxy before modifying it.
#
$tokens = $null
$errors = $null

$ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $proxy,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw `
        "Generated Install-PSResource proxy failed to parse before modification: $($errors[0].Message)"
}

#
# Add the Amiasea help before the generated proxy body.
#
$proxy =
    $injectedHelp.TrimEnd() +
    "`r`n" +
    $proxy

#
# Reparse after adding the help.
#
$tokens = $null
$errors = $null

$ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $proxy,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw `
        "Install-PSResource proxy failed to parse after help was added: $($errors[0].Message)"
}

#
# Locate the generated parameter block.
#
$paramBlock = $ast.ParamBlock

if ($null -eq $paramBlock) {
    throw `
        'Unable to locate generated Install-PSResource parameter block.'
}

#
# Insert the Amiasea-owned switch immediately before the closing
# parenthesis of the generated parameter block.
#
$paramBlockEnd = $paramBlock.Extent.EndOffset - 1

if ($paramBlockEnd -le $paramBlock.Extent.StartOffset) {
    throw `
        'Generated Install-PSResource parameter block has an invalid extent.'
}

$proxy =
    $proxy.Substring(0, $paramBlockEnd) +
    @'
,
    [Parameter()]
    [switch]$UseExternalDependencyResolution
'@ +
    $proxy.Substring($paramBlockEnd)

#
# Reparse after adding the Amiasea parameter.
#
$tokens = $null
$errors = $null

$ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $proxy,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw `
        "Install-PSResource proxy failed to parse after adding UseExternalDependencyResolution: $($errors[0].Message)"
}

#
# Locate the generated begin block after the parameter modification.
#
$beginBlock = $ast.BeginBlock

if ($null -eq $beginBlock) {
    throw `
        'Unable to locate generated Install-PSResource begin block.'
}

$start = $beginBlock.Extent.StartOffset
$end   = $beginBlock.Extent.EndOffset

#
# Replace only the generated begin block.
#
$proxy =
    $proxy.Substring(0, $start) +
    $injectedBegin.Trim() +
    $proxy.Substring($end)

#
# Validate the complete modified proxy text.
#
$tokens = $null
$errors = $null

[void][System.Management.Automation.Language.Parser]::ParseInput(
    $proxy,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw `
        "Modified Install-PSResource proxy failed to parse: $($errors[0].Message)"
}

#
# ProxyCommand::Create() returns the function body. Wrap it in the
# Install-PSResource function definition.
#
$functionSource = @"
function Install-PSResource {
$proxy
}
"@

#
# Validate the final function definition before creating it.
#
$tokens = $null
$errors = $null

[void][System.Management.Automation.Language.Parser]::ParseInput(
    $functionSource,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw `
        "Final Install-PSResource proxy function failed to parse: $($errors[0].Message)"
}

#
# Create the function.
#
. ([scriptblock]::Create($functionSource))

#
# Verify the actual resulting command metadata. This is the authoritative
# check that the Amiasea-owned parameter made it onto the function exposed
# to callers.
#
$finalCommand = Get-Command `
    -Name Install-PSResource `
    -CommandType Function `
    -ErrorAction Stop

if (-not $finalCommand.Parameters.ContainsKey(
    'UseExternalDependencyResolution'
)) {
    throw `
        'Final Install-PSResource proxy does not expose UseExternalDependencyResolution.'
}