$ErrorActionPreference = 'Stop'

$profile = $env:USERPROFILE
$archive = Join-Path $env:RUNNER_TEMP 'windows-desktop-state.zip'
$folders = @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Videos', 'Music', 'ChromeProfile')

foreach ($folder in $folders) {
  New-Item -ItemType Directory -Force -Path (Join-Path $profile $folder) | Out-Null
}

$tarArgs = @('-a', '-c', '-f', $archive, '-C', $profile) + $folders
& tar.exe @tarArgs
if ($LASTEXITCODE -ne 0) {
  throw "Could not archive desktop files (tar exited with code $LASTEXITCODE)."
}
