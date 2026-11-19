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
$chromeProfile = if ($env:DESKTOP_PROFILE_DIR) {
  [System.IO.Path]::GetFullPath($env:DESKTOP_PROFILE_DIR)
} else {
  Join-Path $profile 'ChromeProfile'
}
$applicationRoots = @()
$applicationDirectories = @((Join-Path $env:LOCALAPPDATA 'Programs'))
if ($env:DESKTOP_APPLICATION_DIRS) {
  $applicationDirectories += ($env:DESKTOP_APPLICATION_DIRS -split ';')
}
foreach ($directory in $applicationDirectories) {
  $expandedDirectory = [Environment]::ExpandEnvironmentVariables($directory.Trim())
  if (-not $expandedDirectory) {
    continue
  }

  $applicationPath = [System.IO.Path]::GetFullPath($expandedDirectory)
  if ($applicationRoots.Path -contains $applicationPath) {
    continue
  }

  $identity = $applicationPath.TrimEnd('\').ToUpperInvariant()
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = [BitConverter]::ToString(
      $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))
    ).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha256.Dispose()
  }
  $applicationRoots += [pscustomobject]@{
    Path = $applicationPath
    ArchivePrefix = "__windows_desktop_applications__/$hash/"
  }
}
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
  foreach ($entry in $zip.Entries) {
    $entryName = $entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if ([System.IO.Path]::GetFileName($entryName) -ieq 'desktop.ini') {
      continue
    }

    $isChromeProfile = $entry.FullName.StartsWith(
      '__windows_desktop_chrome_profile__/',
      [System.StringComparison]::Ordinal
    )
    $applicationRoot = $applicationRoots | Where-Object {
      $entry.FullName.StartsWith($_.ArchivePrefix, [System.StringComparison]::Ordinal)
    } | Select-Object -First 1
    if ($isChromeProfile) {
      $relativeName = $entry.FullName.Substring('__windows_desktop_chrome_profile__/'.Length)
      $destinationRoot = $chromeProfile
    } elseif ($entry.FullName.StartsWith('__windows_desktop_applications__/', [System.StringComparison]::Ordinal)) {
      if (-not $applicationRoot) {
        throw "The desktop state contains application files for an unconfigured directory: $($entry.FullName)"
      }
      $relativeName = $entry.FullName.Substring($applicationRoot.ArchivePrefix.Length)
      $destinationRoot = $applicationRoot.Path
    } elseif ($entryName.StartsWith("ChromeProfile$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)) {
      $relativeName = $entryName.Substring("ChromeProfile$([System.IO.Path]::DirectorySeparatorChar)".Length)
      $destinationRoot = $chromeProfile
    } else {
      $relativeName = $entryName
      $destinationRoot = $profile
    }

    $destinationRoot = [System.IO.Path]::GetFullPath($destinationRoot)
    $rootPrefix = $destinationRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $destination = [System.IO.Path]::GetFullPath((Join-Path $destinationRoot $relativeName))
    if (-not $destination.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
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
