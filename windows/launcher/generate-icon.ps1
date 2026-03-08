param(
    [string]$OutputPath = $(Join-Path $PSScriptRoot 'iopaint-launcher.ico')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [float]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2

    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()

    return $path
}

$size = 256
$bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.Clear([System.Drawing.Color]::Transparent)

$backgroundRect = New-Object System.Drawing.RectangleF 16, 16, 224, 224
$backgroundPath = New-RoundedRectanglePath -Rect $backgroundRect -Radius 46
$gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    [System.Drawing.PointF]::new(24, 24),
    [System.Drawing.PointF]::new(232, 232),
    [System.Drawing.Color]::FromArgb(255, 53, 162, 220),
    [System.Drawing.Color]::FromArgb(255, 24, 82, 176)
)
$graphics.FillPath($gradientBrush, $backgroundPath)
$outlinePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(150, 255, 255, 255)), 4
$graphics.DrawPath($outlinePen, $backgroundPath)

$frameRect = New-Object System.Drawing.RectangleF 44, 54, 134, 112
$framePath = New-RoundedRectanglePath -Rect $frameRect -Radius 18
$frameShadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50, 0, 0, 0))
$graphics.TranslateTransform(4, 6)
$graphics.FillPath($frameShadowBrush, $framePath)
$graphics.ResetTransform()

$frameBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$graphics.FillPath($frameBrush, $framePath)
$framePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 225, 233, 245)), 3
$graphics.DrawPath($framePen, $framePath)

$skyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 215, 241, 255))
$graphics.FillRectangle($skyBrush, 56, 66, 110, 74)
$sunBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 193, 79))
$graphics.FillEllipse($sunBrush, 132, 76, 18, 18)

$mountainBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 64, 170, 120))
$mountainPoints = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(60, 140),
    [System.Drawing.PointF]::new(98, 100),
    [System.Drawing.PointF]::new(120, 126),
    [System.Drawing.PointF]::new(142, 106),
    [System.Drawing.PointF]::new(166, 140)
)
$graphics.FillPolygon($mountainBrush, $mountainPoints)
$mountainAccentBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 47, 138, 100))
$mountainAccentPoints = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(104, 140),
    [System.Drawing.PointF]::new(132, 112),
    [System.Drawing.PointF]::new(166, 140)
)
$graphics.FillPolygon($mountainAccentBrush, $mountainAccentPoints)

$graphics.TranslateTransform(174, 172)
$graphics.RotateTransform(-36)

$handleRect = New-Object System.Drawing.RectangleF -64, -18, 118, 36
$handlePath = New-RoundedRectanglePath -Rect $handleRect -Radius 16
$handleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 147, 76))
$graphics.FillPath($handleBrush, $handlePath)
$handlePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(180, 171, 72, 19)), 3
$graphics.DrawPath($handlePen, $handlePath)

$ferruleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 230, 234, 242))
$graphics.FillRectangle($ferruleBrush, 40, -18, 20, 36)
$ferrulePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 184, 190, 202)), 2
$graphics.DrawRectangle($ferrulePen, 40, -18, 20, 36)

$bristleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
$bristlePoints = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(60, -18),
    [System.Drawing.PointF]::new(94, 0),
    [System.Drawing.PointF]::new(60, 18)
)
$graphics.FillPolygon($bristleBrush, $bristlePoints)
$tipBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 37, 99, 235))
$tipPoints = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(80, -8),
    [System.Drawing.PointF]::new(94, 0),
    [System.Drawing.PointF]::new(80, 8)
)
$graphics.FillPolygon($tipBrush, $tipPoints)
$graphics.ResetTransform()

$starBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
$starPoints = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(196, 52),
    [System.Drawing.PointF]::new(202, 68),
    [System.Drawing.PointF]::new(218, 74),
    [System.Drawing.PointF]::new(202, 80),
    [System.Drawing.PointF]::new(196, 96),
    [System.Drawing.PointF]::new(190, 80),
    [System.Drawing.PointF]::new(174, 74),
    [System.Drawing.PointF]::new(190, 68)
)
$graphics.FillPolygon($starBrush, $starPoints)

$stream = New-Object System.IO.MemoryStream
$bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $stream.ToArray()

$iconBytes = New-Object byte[] (22 + $pngBytes.Length)
[BitConverter]::GetBytes([UInt16]0).CopyTo($iconBytes, 0)
[BitConverter]::GetBytes([UInt16]1).CopyTo($iconBytes, 2)
[BitConverter]::GetBytes([UInt16]1).CopyTo($iconBytes, 4)
$iconBytes[6] = 0
$iconBytes[7] = 0
$iconBytes[8] = 0
$iconBytes[9] = 0
[BitConverter]::GetBytes([UInt16]1).CopyTo($iconBytes, 10)
[BitConverter]::GetBytes([UInt16]32).CopyTo($iconBytes, 12)
[BitConverter]::GetBytes([UInt32]$pngBytes.Length).CopyTo($iconBytes, 14)
[BitConverter]::GetBytes([UInt32]22).CopyTo($iconBytes, 18)
[Array]::Copy($pngBytes, 0, $iconBytes, 22, $pngBytes.Length)

[System.IO.File]::WriteAllBytes($OutputPath, $iconBytes)

$stream.Dispose()
$outlinePen.Dispose()
$gradientBrush.Dispose()
$frameShadowBrush.Dispose()
$frameBrush.Dispose()
$framePen.Dispose()
$skyBrush.Dispose()
$sunBrush.Dispose()
$mountainBrush.Dispose()
$mountainAccentBrush.Dispose()
$handleBrush.Dispose()
$handlePen.Dispose()
$ferruleBrush.Dispose()
$ferrulePen.Dispose()
$bristleBrush.Dispose()
$tipBrush.Dispose()
$starBrush.Dispose()
$backgroundPath.Dispose()
$framePath.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Output $OutputPath
