$ErrorActionPreference = 'Stop'

$temp = $env:RUNNER_TEMP
$novnc = Join-Path $temp 'noVNC'
$installer = Join-Path $temp 'tightvnc.msi'
$cloudflared = Join-Path $temp 'cloudflared.exe'

function Wait-ForLocalPort([int]$Port, [string]$ServiceName) {
  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
      $client.Connect('127.0.0.1', $Port)
      return
    } catch {
      Start-Sleep -Seconds 1
    } finally {
      $client.Dispose()
    }
  }
  throw "$ServiceName did not start listening on port $Port."
}

if ($env:DESKTOP_PASSWORD -and $env:DESKTOP_PASSWORD -notmatch '^[a-zA-Z0-9]{1,8}$') {
  throw 'TightVNC passwords must contain 1-8 ASCII letters or numbers.'
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class DesktopDisplay
{
  private const int EnumCurrentSettings = -1;
  private const int ChangeTest = 2;
  private const int DisplayWidth = 0x80000;
  private const int DisplayHeight = 0x100000;

  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
  private struct DevMode
  {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string DeviceName;
    public short SpecVersion;
    public short DriverVersion;
    public short Size;
    public short DriverExtra;
    public int Fields;
    public short Orientation;
    public short PaperSize;
    public short PaperLength;
    public short PaperWidth;
    public short Scale;
    public short Copies;
    public short DefaultSource;
    public short PrintQuality;
    public short Color;
    public short Duplex;
    public short YResolution;
    public short TTOption;
    public short Collate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string FormName;
    public short LogPixels;
    public int BitsPerPel;
    public int PelsWidth;
    public int PelsHeight;
    public int DisplayFlags;
    public int DisplayFrequency;
    public int ICMMethod;
    public int ICMIntent;
    public int MediaType;
    public int DitherType;
    public int Reserved1;
    public int Reserved2;
    public int PanningWidth;
    public int PanningHeight;
  }

  [DllImport("user32.dll", CharSet = CharSet.Auto)]
  private static extern bool EnumDisplaySettings(string deviceName, int modeNumber, ref DevMode devMode);

  [DllImport("user32.dll", CharSet = CharSet.Auto)]
  private static extern int ChangeDisplaySettings(ref DevMode devMode, int flags);

  public static int SetResolution(int width, int height)
  {
    var mode = new DevMode();
    mode.Size = (short)Marshal.SizeOf(typeof(DevMode));
    if (!EnumDisplaySettings(null, EnumCurrentSettings, ref mode))
      throw new InvalidOperationException("Could not read the current display settings.");

    mode.PelsWidth = width;
    mode.PelsHeight = height;
    mode.Fields = DisplayWidth | DisplayHeight;

    var testResult = ChangeDisplaySettings(ref mode, ChangeTest);
    if (testResult != 0)
      return testResult;

    return ChangeDisplaySettings(ref mode, 0);
  }
}
'@

$displayResult = [DesktopDisplay]::SetResolution(1500, 937)
if ($displayResult -ne 0) {
  throw "Could not set the desktop resolution to 1500x937 (display change result $displayResult)."
}

if ($env:DESKTOP_PARSEC -eq 'true') {
  if (-not $env:DESKTOP_PASSWORD) {
    throw 'A VNC password is required when starting the Parsec host.'
  }

  winget install --id Parsec.Parsec --exact --silent --scope machine --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) {
    throw "Parsec installation failed with exit code $LASTEXITCODE."
  }

  $parsec = Join-Path $env:ProgramFiles 'Parsec\parsecd.exe'
  if (-not (Test-Path $parsec)) {
    throw "Parsec host executable was not found at $parsec."
  }
  Start-Process -FilePath $parsec
}

Invoke-WebRequest `
  -Uri 'https://www.tightvnc.com/download/2.8.90/tightvnc-2.8.90-gpl-setup-64bit.msi' `
  -OutFile $installer

$msiArgs = @(
  '/i', $installer, '/quiet', '/norestart',
  'ADDLOCAL=Server',
  'SET_ALLOWLOOPBACK=1',
  'VALUE_OF_ALLOWLOOPBACK=1',
  'SERVER_REGISTER_AS_SERVICE=1',
  'SERVER_ADD_FIREWALL_EXCEPTION=1',
  'SET_USEVNCAUTHENTICATION=1'
)
if ($env:DESKTOP_PASSWORD) {
  $msiArgs += @('VALUE_OF_USEVNCAUTHENTICATION=1', 'SET_PASSWORD=1', "VALUE_OF_PASSWORD=$env:DESKTOP_PASSWORD")
} else {
  $msiArgs += 'VALUE_OF_USEVNCAUTHENTICATION=0'
}

$install = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
if ($install.ExitCode -notin @(0, 3010)) {
  throw "TightVNC installation failed with exit code $($install.ExitCode)."
}

$service = Get-Service -Name tvnserver -ErrorAction Stop
if ($service.Status -ne 'Running') {
  Start-Service -Name tvnserver
}
Wait-ForLocalPort -Port 5900 -ServiceName 'TightVNC'

git clone --depth 1 --branch v1.6.0 https://github.com/novnc/noVNC.git $novnc
if ($LASTEXITCODE -ne 0) {
  throw "Could not download noVNC (exit code $LASTEXITCODE)."
}
python -m pip install --disable-pip-version-check websockify==0.12.0
if ($LASTEXITCODE -ne 0) {
  throw "Could not install websockify (exit code $LASTEXITCODE)."
}
$pythonScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
if ($LASTEXITCODE -ne 0) {
  throw "Could not determine the Python scripts directory (exit code $LASTEXITCODE)."
}
$websockify = Join-Path $pythonScripts 'websockify.exe'
if (-not (Test-Path $websockify)) {
  throw "websockify was not installed at $websockify."
}

$websockifyArgs = @('--web', $novnc, '127.0.0.1:6080', '127.0.0.1:5900')
$websockifyProcess = Start-Process -FilePath $websockify -ArgumentList $websockifyArgs -WindowStyle Hidden -PassThru
Wait-ForLocalPort -Port 6080 -ServiceName 'noVNC'
if ($websockifyProcess.HasExited) {
  throw "websockify exited with code $($websockifyProcess.ExitCode)."
}

Invoke-WebRequest `
  -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' `
  -OutFile $cloudflared

$browser = $env:DESKTOP_BROWSER
$browserPath = switch ($browser) {
  'chrome' { 'C:\Program Files\Google\Chrome\Application\chrome.exe' }
  'chromium' { 'C:\Program Files\Google\Chrome\Application\chrome.exe' }
  'msedge' { 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' }
  'firefox' { 'C:\Program Files\Mozilla Firefox\firefox.exe' }
  default { $null }
}

$browserProcess = $null
if ($browserPath) {
  if (-not (Test-Path $browserPath)) {
    throw "$browser is not installed at $browserPath."
  }

  $browserArgs = @()
  if ($env:DESKTOP_PROFILE_DIR) {
    New-Item -ItemType Directory -Force -Path $env:DESKTOP_PROFILE_DIR | Out-Null
    if ($browser -eq 'firefox') {
      $browserArgs += @('-profile', $env:DESKTOP_PROFILE_DIR)
    } else {
      $browserArgs += "--user-data-dir=$env:DESKTOP_PROFILE_DIR"
    }
  }
  $browserArgs += 'https://duckduckgo.com/'
  $browserProcess = Start-Process -FilePath $browserPath -ArgumentList $browserArgs -PassThru
}

try {
  node .github/actions/windows-desktop/start.js $cloudflared
  if ($LASTEXITCODE -ne 0) {
    throw "Desktop tunnel exited with code $LASTEXITCODE."
  }
} finally {
  if ($browserProcess -and -not $browserProcess.HasExited) {
    Stop-Process -Id $browserProcess.Id -Force
  }
}
