$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$constPath = Join-Path $repoRoot 'web_app\src\lib\const.ts'
$statesPath = Join-Path $repoRoot 'web_app\src\lib\states.ts'
$editorPath = Join-Path $repoRoot 'web_app\src\components\Editor.tsx'
$sliderPath = Join-Path $repoRoot 'web_app\src\components\ui\slider.tsx'

$constContent = Get-Content $constPath -Raw
$statesContent = Get-Content $statesPath -Raw
$editorContent = Get-Content $editorPath -Raw
$sliderContent = Get-Content $sliderPath -Raw

if ($constContent -notmatch 'export const DEFAULT_BRUSH_SIZE = 11\b') {
    throw 'Default brush size is not patched to 11.'
}

$scalePattern = 'get\(\)\.editorState\.baseBrushSize\s*\*\s*get\(\)\.editorState\.brushSizeScale\s*\*\s*0?\.3'
if ($statesContent -notmatch $scalePattern) {
    throw 'Brush size scaling is not patched to 0.3.'
}

if ($editorContent -match '_cleanup') {
    throw 'Download filename still appends _cleanup.'
}

if ($editorContent -notmatch 'className=\"[^\"]*bottom-toolbar-slider[^\"]*w-\[212px\][^\"]*\"') {
    throw 'Bottom toolbar slider width/class override missing.'
}

if ($editorContent -notmatch 'defaultValue=\{\[11\]\}') {
    throw 'Bottom toolbar slider default value is not patched to 11.'
}

if ($editorContent -notmatch 'thumbClassName=\"h-5 w-5\"') {
    throw 'Bottom toolbar slider thumb size override missing.'
}

if ($sliderContent -notmatch 'thumbClassName') {
    throw 'Shared slider component does not support thumb class overrides.'
}

Write-Host 'Frontend customization verification passed.'
