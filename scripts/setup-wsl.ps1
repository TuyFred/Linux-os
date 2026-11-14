# GROUP 2 OS — Windows setup
# Installs Ubuntu WSL so the Linux kernel in linux-master can be compiled.

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "  GROUP 2 OS  -  Linux"
Write-Host "  LEARN • BUILD • CREATE • TOGETHER"
Write-Host ""
Write-Host "Project: $Project"
Write-Host ""

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
$wslReady = $false
if ($wsl) {
	try {
		wsl -e true 2>$null
		if ($LASTEXITCODE -eq 0) { $wslReady = $true }
	} catch {
		$wslReady = $false
	}
}

if (-not $wslReady) {
	Write-Host "Linux is not installed on this PC yet."
	Write-Host "The kernel in linux-master cannot be compiled on Windows directly."
	Write-Host ""
	Write-Host "Do this once:"
	Write-Host "  1. Right-click PowerShell -> Run as administrator"
	Write-Host "  2. Run:"
	Write-Host "       wsl --install -d Ubuntu"
	Write-Host "  3. Restart Windows when asked"
	Write-Host "  4. Open Ubuntu, create a username and password"
	Write-Host "  5. Run this script again, or inside Ubuntu run:"
	Write-Host "       cd `"/mnt/c/Users/USER/GROUP 2 OS`""
	Write-Host "       bash scripts/build.sh laptop"
	Write-Host ""
	exit 1
}

Write-Host "WSL is ready. Starting the GROUP 2 OS build inside Linux..."
$linuxPath = (wsl wslpath -a "$Project").Trim()
wsl -e bash -lc "cd `"$linuxPath`" && bash scripts/build.sh laptop"
