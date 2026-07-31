$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# ищем nasm: сначала в PATH, потом в обычных местах установки
$nasm = (Get-Command nasm -ErrorAction SilentlyContinue).Source
if (-not $nasm) {
    $candidates = @(
        "$env:LOCALAPPDATA\bin\NASM\nasm.exe",
        "$env:ProgramFiles\NASM\nasm.exe",
        "${env:ProgramFiles(x86)}\NASM\nasm.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $nasm = $c; break } }
}
if (-not $nasm) {
    Write-Output "NASM не найден. Установите его с https://www.nasm.us/ или добавьте в PATH."
    exit 1
}

& $nasm -f bin -O1 -o doom.exe doom.asm
if ($LASTEXITCODE -ne 0) { Write-Output "BUILD FAILED"; exit 1 }
$sz = (Get-Item doom.exe).Length
Write-Output ("OK: doom.exe {0} bytes" -f $sz)
