# Build the installable GROUP 2 OS ISO (runs inside WSL Ubuntu).
$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "  GROUP 2 OS laptop installer"
Write-Host "  LEARN • BUILD • CREATE • TOGETHER"
Write-Host ""

$wslReady = $false
try {
	wsl -e true 2>$null
	if ($LASTEXITCODE -eq 0) { $wslReady = $true }
} catch {
	$wslReady = $false
}

if (-not $wslReady) {
	Write-Host "Ubuntu/WSL is required to build an ISO that other laptops can install."
	Write-Host ""
	Write-Host "Open PowerShell as Administrator and run:"
	Write-Host "  wsl --install -d Ubuntu"
	Write-Host ""
	Write-Host "Restart Windows, open Ubuntu, then run this script again."
	Write-Host "Full steps are in INSTALL-ON-LAPTOP.txt"
	exit 1
}

$linuxPath = (wsl wslpath -a "$Project").Trim()
Write-Host "Building GROUP2-OS.iso inside Ubuntu..."
Write-Host "This downloads ~6 GB and can take 1-2 hours."
wsl -e bash -lc "cd `"$linuxPath`" && bash scripts/build.sh laptop"
