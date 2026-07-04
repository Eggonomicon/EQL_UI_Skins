param(
    [Parameter(Mandatory=$true)]
    [double]$Scale,

    [string]$Name = "",

    [string[]]$LayoutFiles = @("default1440.ini", "default4k.ini"),

    [int]$FontBump = 1
)

$ErrorActionPreference = "Stop"

$source = $PSScriptRoot
$uiRoot = Split-Path -Parent $source

if ([string]::IsNullOrWhiteSpace($Name)) {
    $scaleName = [Math]::Round($Scale * 100)
    $Name = "SolariaEQL_Custom_$scaleName"
}

$target = Join-Path $uiRoot $Name
$scaler = Join-Path $source "scale_solaria_4k.ps1"

if (-not (Test-Path -LiteralPath $scaler)) {
    throw "Missing scaler script: $scaler"
}

if (Test-Path -LiteralPath $target) {
    throw "Target already exists: $target"
}

& $scaler `
    -Source $source `
    -Target $target `
    -Scale $Scale `
    -FontBump $FontBump `
    -LayoutFiles $LayoutFiles `
    -ReadmeName "README_CUSTOM_SCALE.txt" `
    -VariantLabel "$Name custom scale"

Write-Output ""
Write-Output "Custom SolariaEQL scale created:"
Write-Output $target
Write-Output ""
Write-Output "Load in EverQuest Legends with Alt+O -> Load UI Skin -> $Name."
