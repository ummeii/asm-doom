param([int]$Tics = 4, [string]$Extra = "")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
& .\build.ps1
if ($LASTEXITCODE -ne 0) { exit 1 }
Remove-Item shot.bmp, shot.png, error.txt -ErrorAction SilentlyContinue
$args = "-shot $Tics"
if ($Extra -ne "") { $args = "$args $Extra" }
$p = Start-Process -FilePath .\doom.exe -ArgumentList $args -PassThru
if (-not $p.WaitForExit(30000)) { $p.Kill(); Write-Output "TIMEOUT" }
else { Write-Output ("exit={0}" -f $p.ExitCode) }
if (Test-Path error.txt) { Write-Output ("ERROR: " + (Get-Content error.txt -Raw)) }
if (Test-Path shot.bmp) {
    Add-Type -AssemblyName System.Drawing
    $b = [System.Drawing.Image]::FromFile((Resolve-Path shot.bmp))
    $b.Save((Join-Path $PWD 'shot.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
    Write-Output "shot.png ready"
} else { Write-Output "NO SCREENSHOT" }
Write-Output "--- log tail ---"
if (Test-Path doom.log) { Get-Content doom.log -Tail 40 }
