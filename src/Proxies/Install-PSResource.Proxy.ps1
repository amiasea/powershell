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

#
# Parse the generated proxy so the process block can be located
# structurally rather than by matching braces with a regular expression.
#
$tokens = $null
$errors = $null

$ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $proxy,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw "Generated Install-PSResource proxy failed to parse before modification: $($errors[0].Message)"
}

$processBlock = $ast.ProcessBlock

if ($null -eq $processBlock) {
    throw "Unable to locate generated Install-PSResource process block."
}

#
# Replace exactly the extent of the top-level process block.
# The AST extent accounts for nested PowerShell script blocks correctly.
#
$start = $processBlock.Extent.StartOffset
$end   = $processBlock.Extent.EndOffset

$proxy =
    $proxy.Substring(0, $start) +
    $injectedProcess.Trim() +
    $proxy.Substring($end)

#
# Validate the modified proxy before creating the function.
#
$tokens = $null
$errors = $null

[void][System.Management.Automation.Language.Parser]::ParseInput(
    $proxy,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw "Modified Install-PSResource proxy failed to parse: $($errors[0].Message)"
}

#
# ProxyCommand::Create() returns the proxy function body, not the function
# definition itself. Wrap it in the Install-PSResource function before
# dot-sourcing so the proxy is defined rather than immediately invoked.
#
$functionSource = @"
function Install-PSResource {
$proxy
}
"@

#
# Validate the complete function definition before creating the scriptblock.
#
$tokens = $null
$errors = $null

[void][System.Management.Automation.Language.Parser]::ParseInput(
    $functionSource,
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    throw "Final Install-PSResource proxy function failed to parse: $($errors[0].Message)"
}

. ([scriptblock]::Create($functionSource))