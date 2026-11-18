$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$profile = $env:USERPROFILE
$archive = Join-Path $env:RUNNER_TEMP 'windows-desktop-state.zip'
$folders = @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Videos', 'Music', 'ChromeProfile')

foreach ($folder in $folders) {
  New-Item -ItemType Directory -Force -Path (Join-Path $profile $folder) | Out-Null
}

if (Test-Path -LiteralPath $archive) {
  Remove-Item -LiteralPath $archive -Force
}

$zip = [System.IO.Compression.ZipFile]::Open(
  $archive,
  [System.IO.Compression.ZipArchiveMode]::Create
)
try {
  foreach ($folder in $folders) {
    $root = Join-Path $profile $folder
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

        $entryName = [System.IO.Path]::GetRelativePath($profile, $entry).Replace('\', '/')
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
