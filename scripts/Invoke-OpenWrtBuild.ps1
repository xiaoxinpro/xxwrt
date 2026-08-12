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

function Invoke-CheckedNativeCommand {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command,

    [Parameter(Mandatory = $true)]
    [string]$FailureMessage
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
}

function Remove-PathIfExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

function Invoke-ShallowClone {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryUrl,

    [Parameter(Mandatory = $true)]
    [string]$Branch,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [Parameter(Mandatory = $false)]
    [string]$Commit
  )

  Remove-PathIfExists -Path $Destination
  Invoke-CheckedNativeCommand `
    -Command { & git clone --depth 1 --single-branch --branch $Branch $RepositoryUrl $Destination } `
    -FailureMessage "Failed to clone $RepositoryUrl branch $Branch."

  if ($Commit) {
    Invoke-CheckedNativeCommand `
      -Command { & git -C $Destination fetch --depth 1 origin $Commit } `
      -FailureMessage "Failed to fetch expected commit $Commit from $RepositoryUrl."
    Invoke-CheckedNativeCommand `
      -Command { & git -C $Destination -c advice.detachedHead=false checkout $Commit } `
      -FailureMessage "Failed to checkout expected commit $Commit from $RepositoryUrl."

    $actualCommit = (& git -C $Destination rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $Commit) {
      throw "Third-party source commit mismatch for $RepositoryUrl. Expected $Commit, got $actualCommit."
    }
  }
}

function Add-HelloworldFeed {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
  )

  $feedsConfigPath = Join-Path $SourceDir 'feeds.conf.default'
  $expectedCommit = $env:THIRD_PARTY_HELLOWORLD_SHA
  if ($expectedCommit) {
    $feedLine = "src-git helloworld https://github.com/fw876/helloworld.git^$expectedCommit"
  }
  else {
    $feedLine = 'src-git helloworld https://github.com/fw876/helloworld.git;dev'
  }
  $lines = @()

  if (Test-Path -LiteralPath $feedsConfigPath) {
    $lines = @(Get-Content -LiteralPath $feedsConfigPath -Encoding UTF8)
  }

  $lines = @($lines | Where-Object { $_ -notmatch '^\s*src-git\s+helloworld\s+' })
  $lines += $feedLine
  Set-Content -LiteralPath $feedsConfigPath -Value $lines -Encoding UTF8
}

function Remove-ThirdPartyPackageConflicts {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
  )

  $conflictPaths = @(
    'feeds/helloworld/mosdns',
    'feeds/packages/net/v2ray-geodata',
    'package/feeds/helloworld/mosdns',
    'package/feeds/packages/v2ray-geodata'
  )

  foreach ($relativePath in $conflictPaths) {
    Remove-PathIfExists -Path (Join-Path $SourceDir $relativePath)
  }
}

function Write-ThirdPartySourceInfo {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
  )

  $sourceInfoPath = Join-Path $SourceDir 'third-party-sources.buildinfo'
  $sources = @(
    @{
      Name = 'helloworld'
      Branch = 'dev'
      Path = Join-Path $SourceDir 'feeds/helloworld'
      Url = 'https://github.com/fw876/helloworld.git'
    },
    @{
      Name = 'luci-app-mosdns'
      Branch = 'v5'
      Path = Join-Path $SourceDir 'package/mosdns'
      Url = 'https://github.com/sbwml/luci-app-mosdns.git'
    },
    @{
      Name = 'v2ray-geodata'
      Branch = 'master'
      Path = Join-Path $SourceDir 'package/v2ray-geodata'
      Url = 'https://github.com/sbwml/v2ray-geodata.git'
    }
  )

  $lines = foreach ($source in $sources) {
    $commit = (& git -C $source.Path rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commit) {
      throw "Failed to resolve third-party source commit: $($source.Name)"
    }

    "$($source.Name) $($source.Branch) $commit $($source.Url)"
  }

  Set-Content -LiteralPath $sourceInfoPath -Value $lines -Encoding UTF8
}

function Install-ThirdPartyPackages {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
  )

  Add-HelloworldFeed -SourceDir $SourceDir

  Invoke-ShallowClone `
    -RepositoryUrl 'https://github.com/sbwml/luci-app-mosdns.git' `
    -Branch 'v5' `
    -Destination (Join-Path $SourceDir 'package/mosdns') `
    -Commit $env:THIRD_PARTY_LUCI_APP_MOSDNS_SHA

  Invoke-ShallowClone `
    -RepositoryUrl 'https://github.com/sbwml/v2ray-geodata.git' `
    -Branch 'master' `
    -Destination (Join-Path $SourceDir 'package/v2ray-geodata') `
    -Commit $env:THIRD_PARTY_V2RAY_GEODATA_SHA
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
  throw "Source directory not found: $SourceDir"
}

if (-not $env:CCACHE_DIR) {
  throw 'CCACHE_DIR is not set.'
}

New-Item -ItemType Directory -Force -Path $env:CCACHE_DIR | Out-Null
$env:CCACHE_COMPRESS = '1'
$env:CCACHE_COMPILERCHECK = 'content'
$env:CCACHE_BASEDIR = $SourceDir
$env:PATH = "/usr/lib/ccache:$env:PATH"

Push-Location $SourceDir
try {
  if (Get-Command ccache -ErrorAction SilentlyContinue) {
    Invoke-CheckedNativeCommand `
      -Command { & ccache -M $env:CCACHE_MAXSIZE | Out-Null } `
      -FailureMessage 'Failed to configure ccache maximum size.'
    Invoke-CheckedNativeCommand `
      -Command { & ccache -z | Out-Null } `
      -FailureMessage 'Failed to reset ccache statistics.'
  }

  Install-ThirdPartyPackages -SourceDir $SourceDir

  Invoke-CheckedNativeCommand `
    -Command { & ./scripts/feeds update -a } `
    -FailureMessage 'Failed to update OpenWrt feeds.'
  Remove-ThirdPartyPackageConflicts -SourceDir $SourceDir
  Invoke-CheckedNativeCommand `
    -Command { & ./scripts/feeds update -i helloworld packages } `
    -FailureMessage 'Failed to rebuild feed indexes after removing conflicting packages.'
  Invoke-CheckedNativeCommand `
    -Command { & ./scripts/feeds install -a } `
    -FailureMessage 'Failed to install OpenWrt feeds.'
  Remove-ThirdPartyPackageConflicts -SourceDir $SourceDir
  Write-ThirdPartySourceInfo -SourceDir $SourceDir

  if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $SourceDir '.config') -Force
  }
  else {
    Write-Host 'No repository config file supplied; using OpenWrt defaults.'
  }

  Invoke-CheckedNativeCommand `
    -Command { & make defconfig } `
    -FailureMessage 'OpenWrt defconfig failed.'

  if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    $assertScript = Join-Path $PSScriptRoot 'Assert-OpenWrtPackages.ps1'
    & $assertScript `
      -RequestedConfigPath $ConfigPath `
      -FinalConfigPath (Join-Path $SourceDir '.config')
  }

  Invoke-CheckedNativeCommand `
    -Command { & make download -j $Jobs } `
    -FailureMessage 'OpenWrt package download failed.'
  Invoke-CheckedNativeCommand `
    -Command { & make $MakeTarget -j $Jobs } `
    -FailureMessage "OpenWrt make target failed: $MakeTarget"

  if (Get-Command ccache -ErrorAction SilentlyContinue) {
    & ccache -s
  }
}
finally {
  Pop-Location
}
