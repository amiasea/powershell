$command = Get-Command `
    -Name Install-PSResource `
    -CommandType Cmdlet `
    -ErrorAction Stop

$proxy = [System.Management.Automation.ProxyCommand]::Create(
    $command
)

$injectedBegin = @'
begin
{
    try {
        #
        # Transform Amiasea installations before the native
        # Install-PSResource steppable pipeline is constructed.
        #
        $amiaseaParameters = ConvertTo-AmiaseaInstallParameters `
            -BoundParameters $PSBoundParameters

        if ($null -ne $amiaseaParameters) {
            $PSBoundParameters = $amiaseaParameters
        }

        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(
            'Microsoft.PowerShell.PSResourceGet\Install-PSResource',
            [System.Management.Automation.CommandTypes]::Cmdlet
        )

        $scriptCmd = {& $wrappedCmd @PSBoundParameters }

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
# Parse the generated proxy so the begin block can be located
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

$beginBlock = $ast.BeginBlock

if ($null -eq $beginBlock) {
    throw "Unable to locate generated Install-PSResource begin block."
}

#
# Replace exactly the extent of the top-level begin block.
# The AST extent accounts for nested PowerShell script blocks correctly.
#
$start = $beginBlock.Extent.StartOffset
$end   = $beginBlock.Extent.EndOffset

$proxy =
    $proxy.Substring(0, $start) +
    $injectedBegin.Trim() +
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