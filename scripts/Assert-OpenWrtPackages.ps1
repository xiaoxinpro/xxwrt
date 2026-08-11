param(
  [Parameter(Mandatory = $false)]
  [string]$RequestedConfigPath,

  [Parameter(Mandatory = $false)]
  [string]$FinalConfigPath,

  [Parameter(Mandatory = $false)]
  [string]$ManifestPath,

  [Parameter(Mandatory = $false)]
  [string[]]$ManifestPackages = @()
)

$ErrorActionPreference = 'Stop'

function Get-SelectedConfigPackages {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $packages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Config file not found: $Path"
  }

  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    if ($line -match '^CONFIG_PACKAGE_(.+)=y$') {
      [void]$packages.Add($Matches[1])
    }
  }

  return $packages
}

function Get-ManifestPackages {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $packages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Manifest file not found: $Path"
  }

  foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
    if ($line -match '^(.+?)\s+-\s+') {
      [void]$packages.Add($Matches[1])
    }
  }

  return $packages
}

if ($RequestedConfigPath -and $FinalConfigPath) {
  $requested = Get-SelectedConfigPackages -Path $RequestedConfigPath
  $final = Get-SelectedConfigPackages -Path $FinalConfigPath
  $missingConfig = @($requested | Where-Object { -not $final.Contains($_) } | Sort-Object)

  if ($missingConfig.Count -gt 0) {
    Write-Host 'Requested packages missing after make defconfig:'
    foreach ($package in $missingConfig) {
      Write-Host "  CONFIG_PACKAGE_$package=y"
    }
    throw 'OpenWrt defconfig removed requested package selections.'
  }

  Write-Host "All requested package config selections survived defconfig: $($requested.Count)"
}

if ($ManifestPath -and $ManifestPackages.Count -gt 0) {
  $manifest = Get-ManifestPackages -Path $ManifestPath
  $missingManifest = @($ManifestPackages | Where-Object { -not $manifest.Contains($_) } | Sort-Object)

  if ($missingManifest.Count -gt 0) {
    Write-Host 'Required runtime packages missing from firmware manifest:'
    foreach ($package in $missingManifest) {
      Write-Host "  $package"
    }
    throw 'Firmware manifest does not contain all required runtime packages.'
  }

  Write-Host "All required runtime packages are present in manifest: $($ManifestPackages.Count)"
}

