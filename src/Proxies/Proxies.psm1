$resolvePath = Join-Path $PSScriptRoot 'Resolve-AmiaseaRequiredResource.ps1'

if (-not (Test-Path $resolvePath -PathType Leaf)) {
    throw "Amiasea resource resolver not found: $resolvePath"
}

. $resolvePath

$convertPath = Join-Path $PSScriptRoot 'ConvertTo-AmiaseaInstallParameters.ps1'

if (-not (Test-Path $convertPath -PathType Leaf)) {
    throw "Amiasea install parameter converter not found: $convertPath"
}

. $convertPath

$proxyPath = Join-Path $PSScriptRoot 'Install-PSResource.Proxy.ps1'

if (-not (Test-Path $proxyPath -PathType Leaf)) {
    throw "Install-PSResource proxy not found: $proxyPath"
}

. $proxyPath