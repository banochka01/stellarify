param(
  [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'
$resonanceRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $resonanceRoot
$pubspecPath = Join-Path $resonanceRoot 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1
if (-not $versionLine) { throw 'Could not read the Resonance version from pubspec.yaml.' }
$version = $versionLine.Matches[0].Groups[1].Value
$flutter = 'K:\SDK\flutter_fresh\bin\flutter.bat'
$releaseDir = Join-Path $resonanceRoot 'build\windows\x64\runner\Release'
$artifactDir = Join-Path $workspaceRoot "artifacts\resonance-$version"
$definition = Join-Path $resonanceRoot 'windows\installer\Resonance.nsi'

if (-not $SkipFlutterBuild) {
  & $flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'The Windows release build failed.' }
}
if (-not (Test-Path -LiteralPath (Join-Path $releaseDir 'resonance.exe'))) {
  throw "The Windows release bundle is missing at $releaseDir."
}

$compilerCandidates = @(
  'C:\Program Files (x86)\NSIS\makensis.exe',
  'C:\Program Files\NSIS\makensis.exe'
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) {
  throw 'NSIS 3 is required. Install package NSIS.NSIS with winget.'
}

New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
& $compiler "/DAPP_VERSION=$version" "/DBUILD_DIR=$releaseDir" "/DOUTPUT_DIR=$artifactDir" $definition
if ($LASTEXITCODE -ne 0) { throw 'The Resonance installer build failed.' }

$installer = Join-Path $artifactDir "Resonance-Setup-$version-x64.exe"
if (-not (Test-Path -LiteralPath $installer)) { throw "Installer was not created at $installer." }
Get-Item -LiteralPath $installer
