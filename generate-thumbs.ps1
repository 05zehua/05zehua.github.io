param(
    [string]$SourceRoot = "timeline_images",
    [string]$ThumbRoot = "timeline_thumbs",
    [int]$MaxWidth = 480,
    [int]$MaxHeight = 360,
    [int]$JpegQuality = 82
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$scriptPath = $MyInvocation.MyCommand.Path
$repoRoot = if ($scriptPath) {
    Split-Path -Parent $scriptPath
} else {
    (Get-Location).Path
}
$sourcePath = Join-Path $repoRoot $SourceRoot
$thumbPath = Join-Path $repoRoot $ThumbRoot

if (!(Test-Path -LiteralPath $sourcePath)) {
    throw "Source directory not found: $sourcePath"
}

if (!(Test-Path -LiteralPath $thumbPath)) {
    New-Item -ItemType Directory -Path $thumbPath -Force | Out-Null
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq "image/jpeg" }

$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality,
    [long]$JpegQuality
)

$created = 0
$skipped = 0
$failed = 0

Get-ChildItem -LiteralPath $sourcePath -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($sourcePath.Length).TrimStart("\", "/")
    $relativeDir = Split-Path -Parent $relative
    $outputDir = Join-Path $thumbPath $relativeDir
    $outputName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + ".jpg"
    $outputFile = Join-Path $outputDir $outputName

    if ((Test-Path -LiteralPath $outputFile) -and
        ((Get-Item -LiteralPath $outputFile).LastWriteTimeUtc -ge $_.LastWriteTimeUtc)) {
        $skipped++
        return
    }

    try {
        if (!(Test-Path -LiteralPath $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $img = [System.Drawing.Image]::FromFile($_.FullName)
        $ratio = [Math]::Min($MaxWidth / $img.Width, $MaxHeight / $img.Height)
        if ($ratio -gt 1) { $ratio = 1 }

        $newWidth = [Math]::Max(1, [int][Math]::Round($img.Width * $ratio))
        $newHeight = [Math]::Max(1, [int][Math]::Round($img.Height * $ratio))

        $bitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)

        $bitmap.Save($outputFile, $jpegCodec, $encoderParams)
        $created++
    } catch {
        $failed++
        Write-Warning "Failed to create thumbnail for $($_.FullName): $($_.Exception.Message)"
    } finally {
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($img) { $img.Dispose() }
        $graphics = $null
        $bitmap = $null
        $img = $null
    }
}

Write-Output "Timeline thumbnails complete. Created/updated: $created, skipped: $skipped, failed: $failed."
