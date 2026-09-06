$resolvePath = Join-Path $PSScriptRoot 'Resolve-AmiaseaRequiredResource.ps1'

if (-not (Test-Path $resolvePath -PathType Leaf)) {
    throw "Amiasea resource resolver not found: $resolvePath"
}

. $resolvePath

$proxyPath = Join-Path $PSScriptRoot 'Install-PSResource.Proxy.ps1'

if (-not (Test-Path $proxyPath -PathType Leaf)) {
    throw "Install-PSResource proxy not found: $proxyPath"
}

. $proxyPath