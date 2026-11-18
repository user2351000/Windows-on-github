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

$profile = [System.IO.Path]::GetFullPath($env:USERPROFILE)
$profilePrefix = $profile.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
  foreach ($entry in $zip.Entries) {
    $entryName = $entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if ([System.IO.Path]::GetFileName($entryName) -ieq 'desktop.ini') {
      continue
    }

    $destination = [System.IO.Path]::GetFullPath((Join-Path $profile $entryName))
    if (-not $destination.StartsWith($profilePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Desktop state archive contains an invalid path: $($entry.FullName)"
    }

    if ($entry.FullName.EndsWith('/')) {
      New-Item -ItemType Directory -Force -Path $destination | Out-Null
      continue
    }

    $parent = [System.IO.Path]::GetDirectoryName($destination)
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
  }
} finally {
  $zip.Dispose()
}
