$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$encrypted = Join-Path $env:RUNNER_TEMP 'windows-desktop-state-download\windows-desktop-state.enc'
if (-not (Test-Path $encrypted)) {
  Write-Host 'No previous desktop files were found; starting with an empty user profile.'
  return
}

$archive = Join-Path $env:RUNNER_TEMP 'windows-desktop-state.zip'
node .github/actions/windows-desktop/state.js decrypt $encrypted $archive
if ($LASTEXITCODE -ne 0) {
  throw "Could not decrypt the previous desktop files (exit code $LASTEXITCODE). Check the repository secret."
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($archive, $env:USERPROFILE, $true)
