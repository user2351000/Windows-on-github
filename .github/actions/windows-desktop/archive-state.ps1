$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$profile = $env:USERPROFILE
$archive = Join-Path $env:RUNNER_TEMP 'windows-desktop-state.zip'
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
  if (-not (Test-Path -LiteralPath $applicationPath -PathType Container)) {
    if ($applicationPath -eq [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))) {
      continue
    }
    throw "Application directory to archive was not found: $applicationPath"
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
$folders = @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Videos', 'Music')

foreach ($folder in $folders) {
  New-Item -ItemType Directory -Force -Path (Join-Path $profile $folder) | Out-Null
}
New-Item -ItemType Directory -Force -Path $chromeProfile | Out-Null

if (Test-Path -LiteralPath $archive) {
  Remove-Item -LiteralPath $archive -Force
}

$zip = [System.IO.Compression.ZipFile]::Open(
  $archive,
  [System.IO.Compression.ZipArchiveMode]::Create
)
try {
  $roots = @(
    foreach ($folder in $folders) {
      [pscustomobject]@{
        Path = Join-Path $profile $folder
        ArchivePrefix = "$folder/"
      }
    }
    [pscustomobject]@{
      Path = $chromeProfile
      ArchivePrefix = '__windows_desktop_chrome_profile__/'
    }
    $applicationRoots
  )

  foreach ($rootInfo in $roots) {
    $root = $rootInfo.Path
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($root)

    while ($pending.Count -gt 0) {
      $directory = $pending.Pop()
      foreach ($entry in [System.IO.Directory]::EnumerateFileSystemEntries($directory)) {
        $attributes = [System.IO.File]::GetAttributes($entry)
        if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
          continue
        }

        if (($attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
          $pending.Push($entry)
          continue
        }
        if ([System.IO.Path]::GetFileName($entry) -ieq 'desktop.ini') {
          continue
        }

        $relativeName = [System.IO.Path]::GetRelativePath($root, $entry).Replace('\', '/')
        $entryName = "$($rootInfo.ArchivePrefix)$relativeName"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $zip,
          $entry,
          $entryName,
          [System.IO.Compression.CompressionLevel]::Fastest
        ) | Out-Null
      }
    }
  }
} finally {
  $zip.Dispose()
}
