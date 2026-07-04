param(
    [string]$SkinPath = $PSScriptRoot,
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

function Clamp-Byte {
    param([double]$Value)
    return [byte]([Math]::Max(0, [Math]::Min(255, [Math]::Round($Value))))
}

function Read-Tga32 {
    param([string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 18) {
        throw "Invalid TGA header: $Path"
    }

    $type = [int]$bytes[2]
    $width = [BitConverter]::ToUInt16($bytes, 12)
    $height = [BitConverter]::ToUInt16($bytes, 14)
    $bpp = [int]$bytes[16]
    $descriptor = [int]$bytes[17]
    if ($bpp -ne 24 -and $bpp -ne 32) {
        throw "Unsupported TGA bpp $bpp in $Path"
    }
    if ($type -ne 2 -and $type -ne 10) {
        throw "Unsupported TGA image type $type in $Path"
    }

    $idLength = [int]$bytes[0]
    $colorMapLength = [BitConverter]::ToUInt16($bytes, 5)
    $colorMapEntryBits = [int]$bytes[7]
    $colorMapBytes = $colorMapLength * [int][Math]::Ceiling($colorMapEntryBits / 8.0)
    $offset = 18 + $idLength + $colorMapBytes
    $sourceBytesPerPixel = [int]($bpp / 8)
    $pixelCount = $width * $height
    $pixels = New-Object byte[] ($pixelCount * 4)

    if ($type -eq 2) {
        for ($i = 0; $i -lt $pixelCount; $i++) {
            $src = $offset + ($i * $sourceBytesPerPixel)
            $dst = $i * 4
            $pixels[$dst] = $bytes[$src]
            $pixels[$dst + 1] = $bytes[$src + 1]
            $pixels[$dst + 2] = $bytes[$src + 2]
            $pixels[$dst + 3] = if ($sourceBytesPerPixel -eq 4) { $bytes[$src + 3] } else { 255 }
        }
    }
    else {
        $src = $offset
        $i = 0
        while ($i -lt $pixelCount -and $src -lt $bytes.Length) {
            $packet = [int]$bytes[$src]
            $src++
            $count = ($packet -band 0x7F) + 1
            if (($packet -band 0x80) -ne 0) {
                $b = $bytes[$src]
                $g = $bytes[$src + 1]
                $r = $bytes[$src + 2]
                $a = if ($sourceBytesPerPixel -eq 4) { $bytes[$src + 3] } else { 255 }
                $src += $sourceBytesPerPixel
                for ($j = 0; $j -lt $count -and $i -lt $pixelCount; $j++, $i++) {
                    $dst = $i * 4
                    $pixels[$dst] = $b
                    $pixels[$dst + 1] = $g
                    $pixels[$dst + 2] = $r
                    $pixels[$dst + 3] = $a
                }
            }
            else {
                for ($j = 0; $j -lt $count -and $i -lt $pixelCount; $j++, $i++) {
                    $dst = $i * 4
                    $pixels[$dst] = $bytes[$src]
                    $pixels[$dst + 1] = $bytes[$src + 1]
                    $pixels[$dst + 2] = $bytes[$src + 2]
                    $pixels[$dst + 3] = if ($sourceBytesPerPixel -eq 4) { $bytes[$src + 3] } else { 255 }
                    $src += $sourceBytesPerPixel
                }
            }
        }
    }

    return [pscustomobject]@{
        Width = $width
        Height = $height
        Descriptor = $descriptor
        Pixels = $pixels
    }
}

function Write-Tga32 {
    param(
        [string]$Path,
        [int]$Width,
        [int]$Height,
        [int]$Descriptor,
        [byte[]]$Pixels
    )

    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = [byte]($Width -band 0xFF)
    $header[13] = [byte](($Width -shr 8) -band 0xFF)
    $header[14] = [byte]($Height -band 0xFF)
    $header[15] = [byte](($Height -shr 8) -band 0xFF)
    $header[16] = 32
    $header[17] = [byte](($Descriptor -band 0x30) -bor 8)
    [IO.File]::WriteAllBytes($Path, $header + $Pixels)
}

function Protect-Original {
    param(
        [string]$SkinPath,
        [string]$RelativePath
    )

    if ($NoBackup) {
        return
    }

    $source = Join-Path $SkinPath $RelativePath
    $backupRoot = Join-Path $SkinPath "_dev\original_art_backups\solariaeql_artpack_v1"
    $backup = Join-Path $backupRoot $RelativePath
    if (-not (Test-Path -LiteralPath $backup)) {
        $backupDir = Split-Path -Parent $backup
        if (-not (Test-Path -LiteralPath $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $backup
    }
}

function Convert-PixelToSolariaEql {
    param(
        [int]$R,
        [int]$G,
        [int]$B,
        [int]$A,
        [int]$X,
        [int]$Y,
        [string]$Mode
    )

    if ($A -eq 0) {
        return @(0, 0, 0, 0)
    }

    $lum = (($R * 0.2126) + ($G * 0.7152) + ($B * 0.0722)) / 255.0
    $max = [Math]::Max($R, [Math]::Max($G, $B))
    $min = [Math]::Min($R, [Math]::Min($G, $B))
    $sat = if ($max -eq 0) { 0 } else { ($max - $min) / [double]$max }
    $noise = ((($X * 17 + $Y * 31) % 17) - 8) / 255.0

    if ($Mode -eq "background") {
        $vein1 = [Math]::Abs((($X * 3 + $Y * 5) % 97) - 48)
        $vein2 = [Math]::Abs((($X * 7 - $Y * 2) % 113) - 56)
        $base = 20 + ($lum * 34) + ($noise * 24)
        $outR = $base * 0.86
        $outG = $base * 1.00
        $outB = $base * 0.85
        if ($vein1 -lt 2.2 -or $vein2 -lt 1.8) {
            $outR += 10
            $outG += 48
            $outB += 29
        }
        if ((($X + $Y) % 61) -eq 0) {
            $outR += 34
            $outG += 24
            $outB += 6
        }
        return @((Clamp-Byte $outB), (Clamp-Byte $outG), (Clamp-Byte $outR), [byte]$A)
    }

    $emeraldBias = ($G -gt ($R + 18) -and $G -gt ($B + 8))
    $goldBias = ($R -ge $G -and $G -ge $B -and $sat -gt 0.12)

    if ($lum -gt 0.62 -or $goldBias) {
        $outR = 104 + ($lum * 126)
        $outG = 70 + ($lum * 82)
        $outB = 28 + ($lum * 36)
    }
    elseif ($emeraldBias) {
        $outR = 18 + ($lum * 38)
        $outG = 72 + ($lum * 118)
        $outB = 42 + ($lum * 72)
    }
    elseif ($lum -gt 0.34) {
        $outR = 42 + ($lum * 78)
        $outG = 33 + ($lum * 58)
        $outB = 20 + ($lum * 38)
    }
    else {
        $outR = 12 + ($lum * 62)
        $outG = 14 + ($lum * 58)
        $outB = 13 + ($lum * 48)
    }

    if ((($X * 11 + $Y * 13) % 79) -eq 0 -and $lum -gt 0.2) {
        $outR += 18
        $outG += 12
        $outB += 3
    }

    return @((Clamp-Byte ($outB + ($noise * 20))), (Clamp-Byte ($outG + ($noise * 20))), (Clamp-Byte ($outR + ($noise * 20))), [byte]$A)
}

function Convert-TgaTheme {
    param(
        [string]$SkinPath,
        [string]$RelativePath,
        [string]$Mode = "atlas"
    )

    $path = Join-Path $SkinPath $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return $false
    }

    Protect-Original -SkinPath $SkinPath -RelativePath $RelativePath
    $image = Read-Tga32 -Path $path
    $pixels = $image.Pixels
    for ($y = 0; $y -lt $image.Height; $y++) {
        for ($x = 0; $x -lt $image.Width; $x++) {
            $idx = (($y * $image.Width) + $x) * 4
            $converted = Convert-PixelToSolariaEql -B $pixels[$idx] -G $pixels[$idx + 1] -R $pixels[$idx + 2] -A $pixels[$idx + 3] -X $x -Y $y -Mode $Mode
            $pixels[$idx] = $converted[0]
            $pixels[$idx + 1] = $converted[1]
            $pixels[$idx + 2] = $converted[2]
            $pixels[$idx + 3] = $converted[3]
        }
    }
    Write-Tga32 -Path $path -Width $image.Width -Height $image.Height -Descriptor $image.Descriptor -Pixels $pixels
    return $true
}

function New-SolariaEqlBackground {
    param([string]$SkinPath)

    $relativePath = "solariaeql_wnd_bg.tga"
    Protect-Original -SkinPath $SkinPath -RelativePath $relativePath

    $width = 256
    $height = 256
    $pixels = New-Object byte[] ($width * $height * 4)
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $idx = (($y * $width) + $x) * 4
            $syntheticLum = 0.38 + ([Math]::Sin(($x * 0.13) + ($y * 0.07)) * 0.05) + ([Math]::Sin(($x * 0.031) - ($y * 0.11)) * 0.05)
            $sourceR = [int](255 * $syntheticLum)
            $sourceG = [int](255 * $syntheticLum)
            $sourceB = [int](255 * $syntheticLum)
            $converted = Convert-PixelToSolariaEql -R $sourceR -G $sourceG -B $sourceB -A 255 -X $x -Y $y -Mode "background"
            $pixels[$idx] = $converted[0]
            $pixels[$idx + 1] = $converted[1]
            $pixels[$idx + 2] = $converted[2]
            $pixels[$idx + 3] = $converted[3]
        }
    }

    Write-Tga32 -Path (Join-Path $SkinPath $relativePath) -Width $width -Height $height -Descriptor 0x28 -Pixels $pixels
}

function Save-TgaPreviewPng {
    param(
        [string]$TgaPath,
        [string]$PngPath
    )

    Add-Type -AssemblyName System.Drawing
    $image = Read-Tga32 -Path $TgaPath
    $bitmap = [System.Drawing.Bitmap]::new($image.Width, $image.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        for ($y = 0; $y -lt $image.Height; $y++) {
            for ($x = 0; $x -lt $image.Width; $x++) {
                $idx = (($y * $image.Width) + $x) * 4
                $color = [System.Drawing.Color]::FromArgb($image.Pixels[$idx + 3], $image.Pixels[$idx + 2], $image.Pixels[$idx + 1], $image.Pixels[$idx])
                $bitmap.SetPixel($x, $y, $color)
            }
        }
        $previewDir = Split-Path -Parent $PngPath
        if (-not (Test-Path -LiteralPath $previewDir)) {
            New-Item -ItemType Directory -Path $previewDir | Out-Null
        }
        $bitmap.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

$skinPath = [IO.Path]::GetFullPath($SkinPath)
if (-not (Test-Path -LiteralPath $skinPath)) {
    throw "Skin path not found: $skinPath"
}

$atlasFiles = @(
    "window_pieces01.tga",
    "window_br_pieces.tga",
    "window_br_pieces01a.tga",
    "window_fg_pieces.tga",
    "window_fg_pieces_black.tga",
    "window_pieces02.tga",
    "window_pieces03.tga",
    "window_pieces04.tga",
    "window_pieces05.tga",
    "window_pieces06.tga",
    "window_pieces07.tga",
    "window_pieces08.tga",
    "window_pieces09.tga",
    "window_pieces10.tga",
    "window_pieces11.tga",
    "wnd_bg_light_rock.tga",
    "wnd_bg_light_rock_inner.tga",
    "wnd_bg_dark_rock.tga",
    "wnd_fg_dark_rock.tga",
    "scrollbar_gutter.tga",
    "scrollbar_Hgutter.tga"
)

$changed = @()
foreach ($file in $atlasFiles) {
    $mode = if ($file -match "^wnd_|scrollbar") { "background" } else { "atlas" }
    if (Convert-TgaTheme -SkinPath $skinPath -RelativePath $file -Mode $mode) {
        $changed += $file
    }
}

New-SolariaEqlBackground -SkinPath $skinPath
$changed += "solariaeql_wnd_bg.tga"

$previewDir = Join-Path $skinPath "_dev\generated_assets"
if (Test-Path -LiteralPath $previewDir) {
    Save-TgaPreviewPng -TgaPath (Join-Path $skinPath "solariaeql_wnd_bg.tga") -PngPath (Join-Path $previewDir "solariaeql_wnd_bg_preview.png")
    Save-TgaPreviewPng -TgaPath (Join-Path $skinPath "window_pieces01.tga") -PngPath (Join-Path $previewDir "solariaeql_window_pieces01_preview.png")
    Save-TgaPreviewPng -TgaPath (Join-Path $skinPath "window_fg_pieces.tga") -PngPath (Join-Path $previewDir "solariaeql_window_fg_pieces_preview.png")
}

Write-Output "SolariaEQL art pack applied to: $skinPath"
Write-Output "Themed TGA files: $($changed.Count)"
