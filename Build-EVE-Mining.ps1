# Optional: rebuild the included GUI launcher with Windows PowerShell 5.1.
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-EVE-Mining.ps1
param([string]$OutputName='EVE-Mining.exe')
$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
$automation=[psobject].Assembly.Location
& $compiler '/nologo' '/target:winexe' '/platform:anycpu' ('/reference:'+$automation) '/reference:System.Windows.Forms.dll' '/reference:System.Core.dll' ('/win32icon:'+(Join-Path $PSScriptRoot 'EVE-Mining.ico')) ('/out:'+(Join-Path $PSScriptRoot $OutputName)) (Join-Path $PSScriptRoot 'EVE-Mining-Launcher.cs')
if ($LASTEXITCODE -ne 0) {throw 'Launcher build failed.'}
if ($OutputName -ne 'EVE-Mining.exe') {Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'EVE-Mining.exe.config') -Destination (Join-Path $PSScriptRoot ($OutputName+'.config')) -Force}
