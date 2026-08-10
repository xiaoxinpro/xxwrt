param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDir,

  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [Parameter(Mandatory = $true)]
  [string]$MakeTarget,

  [Parameter(Mandatory = $true)]
  [int]$Jobs
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDir)) {
  throw "Source directory not found: $SourceDir"
}

if (-not $env:CCACHE_DIR) {
  throw 'CCACHE_DIR is not set.'
}

New-Item -ItemType Directory -Force -Path $env:CCACHE_DIR | Out-Null
$env:PATH = "/usr/lib/ccache:$env:PATH"

Push-Location $SourceDir
try {
  if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $SourceDir '.config') -Force
  }
  else {
    Write-Host 'No repository config file supplied; using OpenWrt defaults.'
  }

  if (Get-Command ccache -ErrorAction SilentlyContinue) {
    & ccache -M $env:CCACHE_MAXSIZE | Out-Null
  }

  & ./scripts/feeds update -a
  & ./scripts/feeds install -a
  & make defconfig

  & make download -j $Jobs
  & make $MakeTarget -j $Jobs
}
finally {
  Pop-Location
}
