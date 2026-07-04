param(
    [string]$Source = (Get-Location).Path,
    [string]$Target = (Join-Path (Split-Path -Parent (Get-Location).Path) "Solaria_4K_150"),
    [double]$Scale = 1.5,
    [int]$FontBump = 1,
    [string[]]$LayoutFiles = @("default4k.ini"),
    [string]$ReadmeName = "README_SCALE.txt",
    [string]$VariantLabel = ""
)

$ErrorActionPreference = "Stop"

function Scale-IntegerAwayFromZero {
    param(
        [int]$Value,
        [double]$Factor
    )

    $scaled = $Value * $Factor
    if ($Value -gt 0) {
        return [int][Math]::Ceiling($scaled)
    }
    if ($Value -lt 0) {
        return [int][Math]::Floor($scaled)
    }
    return 0
}

function Has-AtlasAncestor {
    param([System.Xml.XmlNode]$Node)

    $cursor = $Node.ParentNode
    while ($null -ne $cursor) {
        if ($cursor.Name -eq "TextureInfo" -or $cursor.Name -eq "Ui2DAnimation") {
            return $true
        }
        $cursor = $cursor.ParentNode
    }
    return $false
}

$scaleTags = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@(
    "X", "Y", "CX", "CY",
    "Width", "CellWidth", "CellHeight", "ListHeight", "TabWidth",
    "MinHSize", "MinVSize", "MaxHSize", "MaxVSize",
    "TopAnchorOffset", "BottomAnchorOffset", "LeftAnchorOffset", "RightAnchorOffset",
    "TextOffsetX", "TextOffsetY", "GaugeOffsetX", "GaugeOffsetY",
    "SpellIconOffsetX", "SpellIconOffsetY", "SpellIconSizeX", "SpellIconSizeY",
    "Padding", "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
    "Spacing", "SecondarySpacing",
    "OverlapTop", "OverlapBottom", "OverlapLeft", "OverlapRight",
    "FontShadowOffset"
) | ForEach-Object { [void]$scaleTags.Add($_) }

$sourcePath = [IO.Path]::GetFullPath($Source)
$targetPath = [IO.Path]::GetFullPath($Target)
if ([string]::IsNullOrWhiteSpace($VariantLabel)) {
    $VariantLabel = Split-Path -Leaf $targetPath
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source folder not found: $sourcePath"
}

if (Test-Path -LiteralPath $targetPath) {
    throw "Target already exists: $targetPath. Move or delete it before rerunning."
}

New-Item -ItemType Directory -Path $targetPath | Out-Null
Get-ChildItem -LiteralPath $sourcePath -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Recurse -Force
}

$xmlFiles = Get-ChildItem -LiteralPath $targetPath -Filter "*.xml" -File
$scaledNodeCount = 0
$fontNodeCount = 0
$preScaledNoopCount = 0
$preScaledNormalizedCount = 0

foreach ($file in $xmlFiles) {
    $rawXml = Get-Content -LiteralPath $file.FullName -Raw
    $effectiveScale = $Scale
    if ($rawXml -match "Scale factor\s*:\s*([0-9]+(?:\.[0-9]+)?)x") {
        $sourceScale = [double]$matches[1]
        if ($sourceScale -gt 0) {
            $effectiveScale = $Scale / $sourceScale
            if ([Math]::Abs($effectiveScale - 1.0) -lt 0.000001) {
                $preScaledNoopCount++
                continue
            }

            $preScaledNormalizedCount++
            $scaleText = $Scale.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)
            $sourceScaleText = $sourceScale.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)
            $rawXml = $rawXml -replace "Scale factor\s*:\s*[0-9]+(?:\.[0-9]+)?x.*", "Generated target scale : ${scaleText}x (normalized from source ${sourceScaleText}x)"
        }
    }

    $doc = [System.Xml.XmlDocument]::new()
    $doc.PreserveWhitespace = $true
    $doc.LoadXml($rawXml)

    $changed = $false
    foreach ($node in $doc.SelectNodes("//*")) {
        if ($node.ChildNodes.Count -ne 1 -or $node.FirstChild.NodeType -ne [System.Xml.XmlNodeType]::Text) {
            continue
        }

        $text = $node.InnerText.Trim()
        if (-not [regex]::IsMatch($text, "^-?\d+$")) {
            continue
        }

        if (Has-AtlasAncestor -Node $node) {
            continue
        }

        if ($scaleTags.Contains($node.Name)) {
            $oldValue = [int]$text
            $newValue = Scale-IntegerAwayFromZero -Value $oldValue -Factor $effectiveScale
            if ($newValue -ne $oldValue) {
                $node.InnerText = [string]$newValue
                $changed = $true
                $scaledNodeCount++
            }
            continue
        }

        if ($node.Name -eq "Font" -and $FontBump -gt 0) {
            $oldFont = [int]$text
            if ($oldFont -gt 0) {
                $newFont = [Math]::Min(6, $oldFont + $FontBump)
                if ($newFont -ne $oldFont) {
                    $node.InnerText = [string]$newFont
                    $changed = $true
                    $fontNodeCount++
                }
            }
        }
    }

    if ($changed) {
        $doc.Save($file.FullName)
    }
}

$scaledLayoutFiles = @()
foreach ($layoutFile in $LayoutFiles) {
    $layoutPath = Join-Path $targetPath $layoutFile
    if (-not (Test-Path -LiteralPath $layoutPath)) {
        continue
    }

    $skinName = Split-Path -Leaf $targetPath
    $layout = Get-Content -LiteralPath $layoutPath
    $layout = $layout | ForEach-Object {
        $line = $_
        if ($line -match "^UISkin=") {
            return "UISkin=$skinName"
        }
        if ($line -match "^(Width|Height)=(-?\d+)$") {
            $name = $matches[1]
            $value = [int]$matches[2]
            return "$name=$(Scale-IntegerAwayFromZero -Value $value -Factor $Scale)"
        }
        return $line
    }
    Set-Content -LiteralPath $layoutPath -Value $layout -Encoding ASCII
    $scaledLayoutFiles += $layoutFile
}

$readmePath = Join-Path $targetPath $ReadmeName
@(
    "$VariantLabel generated scale pass",
    ("=" * ($VariantLabel.Length + 29)),
    "",
    "Source: $sourcePath",
    "Scale: $Scale",
    "Font bump: +$FontBump, capped at 6",
    "",
    "Scaled XML window/control geometry tags such as X, Y, CX, CY, anchor offsets, min/max sizes, padding, spacing, and icon/gauge offsets.",
    "Preserved TextureInfo and Ui2DAnimation descendants so art atlas coordinates are not changed.",
    "Normalized source XML files already marked with a Scale factor so generated variants are not double-scaled.",
    "Scaled layout file(s): $($scaledLayoutFiles -join ', ')",
    "Set UISkin to $(Split-Path -Leaf $targetPath) in scaled layout files.",
    "",
    "Loading in EverQuest Legends:",
    "Open Options with Alt+O, choose Load UI Skin, select $(Split-Path -Leaf $targetPath), then click Load Skin.",
    "The EQL wiki notes that right-click menus are window-specific, so hotbar-only options such as button size are not automatically available on every UI window.",
    "",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
) | Set-Content -LiteralPath $readmePath -Encoding ASCII

Write-Output "Generated: $targetPath"
Write-Output "Scaled XML numeric nodes: $scaledNodeCount"
Write-Output "Bumped XML font nodes: $fontNodeCount"
Write-Output "Skipped already-at-target pre-scaled XML files: $preScaledNoopCount"
Write-Output "Normalized pre-scaled XML files: $preScaledNormalizedCount"
Write-Output "Scaled layout files: $($scaledLayoutFiles -join ', ')"
