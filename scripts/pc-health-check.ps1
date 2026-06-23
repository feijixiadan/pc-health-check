param(
    [switch]$OpenReport,
    [switch]$RedactIdentity,
    [switch]$HtmlReport
)

$ErrorActionPreference = "SilentlyContinue"

function Format-Bytes {
    param([double]$Bytes)
    if ($null -eq $Bytes) { return "" }
    if ($Bytes -ge 1TB) { return ("{0:N2} TB" -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0:N0} B" -f $Bytes)
}

function Add-Line {
    param([string]$Text = "")
    [void]$script:Lines.Add($Text)
}

function Add-Section {
    param([string]$Title)
    Add-Line ""
    Add-Line ("==== {0} ====" -f $Title)
}

function Format-DateValue {
    param($Value, [string]$Format = "yyyy-MM-dd")
    if ($null -eq $Value) { return "" }
    try {
        return ([datetime]$Value).ToString($Format)
    } catch {
        return [string]$Value
    }
}

function Format-Html {
    param($Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Redact-Text {
    param($Value)

    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    if (-not $RedactIdentity) { return $text }

    $replacements = @(
        @{ Value = $env:USERPROFILE; Replacement = "[redacted-user-profile]" },
        @{ Value = $env:LOCALAPPDATA; Replacement = "[redacted-localappdata]" },
        @{ Value = $env:APPDATA; Replacement = "[redacted-appdata]" },
        @{ Value = $env:TEMP; Replacement = "[redacted-temp]" },
        @{ Value = $env:TMP; Replacement = "[redacted-temp]" },
        @{ Value = $env:COMPUTERNAME; Replacement = "[redacted-computer]" },
        @{ Value = $env:USERNAME; Replacement = "[redacted-user]" }
    )

    foreach ($item in $replacements) {
        if (-not [string]::IsNullOrWhiteSpace($item.Value)) {
            $escaped = [regex]::Escape([string]$item.Value)
            $text = [regex]::Replace($text, $escaped, $item.Replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
    }

    $text = [regex]::Replace($text, '(?i)\b[A-Z]:[\\/]+Users[\\/]+[^\\/\s|]+', '[redacted-user-profile]')
    return $text
}

function Redact-ExtensionIds {
    param([string[]]$Ids)

    if (-not $RedactIdentity) { return @($Ids) }

    $index = 0
    return @($Ids | ForEach-Object {
        $index += 1
        "[redacted-extension-id-$index]"
    })
}

function Get-RegistryValuesSafe {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $item = Get-ItemProperty -Path $Path
    if ($null -eq $item) { return $null }
    $result = [ordered]@{}
    foreach ($prop in $item.PSObject.Properties) {
        if ($prop.Name -notmatch '^PS') {
            $result[$prop.Name] = Redact-Text $prop.Value
        }
    }
    return $result
}

function Get-FolderSizeQuick {
    param(
        [string]$Path,
        [int]$MaxFiles = 20000
    )

    $bytes = 0L
    $count = 0
    $limited = $false

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return [ordered]@{
            Path = Redact-Text $Path
            Exists = $false
            FileCount = 0
            SizeBytes = 0
            Size = "0 B"
            Limited = $false
        }
    }

    try {
        Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $bytes += $_.Length
            $count += 1
            if ($count -ge $MaxFiles) {
                $limited = $true
                throw "Reached file scan limit"
            }
        }
    } catch {
        # Large scans and access denied errors are intentionally tolerated.
    }

    return [ordered]@{
        Path = Redact-Text $Path
        Exists = $true
        FileCount = $count
        SizeBytes = $bytes
        Size = Format-Bytes $bytes
        Limited = $limited
    }
}

function Get-BrowserExtensionIds {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -Directory | Select-Object -ExpandProperty Name)
}

function Maybe-Redact {
    param([string]$Value, [string]$Replacement = "[redacted]")
    if ($RedactIdentity) { return $Replacement }
    return $Value
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$desktop = [Environment]::GetFolderPath("Desktop")
if ([string]::IsNullOrWhiteSpace($desktop)) {
    $desktop = $env:TEMP
}

$txtPath = Join-Path $desktop ("PC-Health-Report-{0}.txt" -f $stamp)
$jsonPath = Join-Path $desktop ("PC-Health-Report-{0}.json" -f $stamp)
$htmlPath = Join-Path $desktop ("PC-Health-Report-{0}.html" -f $stamp)
$script:Lines = New-Object System.Collections.Generic.List[string]
$findings = New-Object System.Collections.Generic.List[string]
$redactedFields = @()
if ($RedactIdentity) {
    $redactedFields = @(
        "computer name",
        "Windows username",
        "known user profile paths",
        "temporary folder paths",
        "startup command user",
        "browser extension IDs",
        "registry policy values that contain local identity paths",
        "console report paths"
    )
}

$isAdmin = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}

$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$computer = Get-CimInstance Win32_ComputerSystem

$uptimeText = ""
if ($os.LastBootUpTime) {
    $uptime = (Get-Date) - $os.LastBootUpTime
    $uptimeText = "{0} days {1} hours {2} minutes" -f [int]$uptime.TotalDays, $uptime.Hours, $uptime.Minutes
}

$totalMemBytes = [double]$os.TotalVisibleMemorySize * 1KB
$freeMemBytes = [double]$os.FreePhysicalMemory * 1KB
$usedMemPercent = if ($totalMemBytes -gt 0) { [math]::Round((1 - ($freeMemBytes / $totalMemBytes)) * 100, 1) } else { 0 }
$cpuLoad = if ($cpu.LoadPercentage -ne $null) { [int]$cpu.LoadPercentage } else { 0 }

$diskTotal = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object { $_.Name -eq "_Total" } | Select-Object -First 1
$diskBusy = if ($diskTotal.PercentDiskTime -ne $null) { [math]::Round([double]$diskTotal.PercentDiskTime, 1) } else { $null }

$drives = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freePercent = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
    [ordered]@{
        Drive = $_.DeviceID
        VolumeName = $_.VolumeName
        Size = Format-Bytes $_.Size
        Free = Format-Bytes $_.FreeSpace
        FreePercent = $freePercent
    }
})

$cDrive = $drives | Where-Object { $_.Drive -eq "C:" } | Select-Object -First 1
if ($usedMemPercent -ge 85) { [void]$findings.Add("Memory usage is high: $usedMemPercent%. Consider closing background apps or adding RAM.") }
if ($cpuLoad -ge 80) { [void]$findings.Add("CPU load is high: $cpuLoad%. Check top processes before optimizing.") }
if ($diskBusy -ne $null -and $diskBusy -ge 80) { [void]$findings.Add("Disk activity is high: $diskBusy%. Old HDD, antivirus scan, or Windows Update may be causing lag.") }
if ($cDrive -and $cDrive.FreePercent -lt 15) { [void]$findings.Add("C drive free space is low: $($cDrive.FreePercent)%. Freeing space may noticeably improve performance.") }

$topMemoryProcesses = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | ForEach-Object {
    [ordered]@{
        Name = $_.ProcessName
        Id = $_.Id
        Memory = Format-Bytes $_.WorkingSet64
        CPUSeconds = if ($_.CPU -ne $null) { [math]::Round($_.CPU, 1) } else { $null }
    }
})

$startupCommands = @(Get-CimInstance Win32_StartupCommand | Sort-Object Location, Name | ForEach-Object {
    [ordered]@{
        Name = $_.Name
        Location = Redact-Text $_.Location
        User = Maybe-Redact $_.User
    }
})
if ($startupCommands.Count -ge 20) { [void]$findings.Add("Startup item count is high: $($startupCommands.Count). Disabling unnecessary startup apps may help boot speed.") }

$autoServices = @(Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq "Auto" -and $_.State -eq "Running" } | Sort-Object DisplayName | Select-Object -First 80 | ForEach-Object {
    [ordered]@{
        DisplayName = $_.DisplayName
        Name = $_.Name
        State = $_.State
    }
})

$antivirus = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object {
    [ordered]@{
        DisplayName = $_.displayName
        ProductState = $_.productState
    }
})
if ($antivirus.Count -gt 1) { [void]$findings.Add("Multiple antivirus products detected: $($antivirus.Count). Conflicts can cause lag.") }

$defender = $null
if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
    $mp = Get-MpComputerStatus
    $defender = [ordered]@{
        AMServiceEnabled = $mp.AMServiceEnabled
        AntivirusEnabled = $mp.AntivirusEnabled
        RealTimeProtectionEnabled = $mp.RealTimeProtectionEnabled
        QuickScanAge = $mp.QuickScanAge
        AntivirusSignatureLastUpdated = $mp.AntivirusSignatureLastUpdated
    }
}

$wuServices = @(Get-Service -Name wuauserv, bits, usosvc -ErrorAction SilentlyContinue | ForEach-Object {
    [ordered]@{
        Name = $_.Name
        DisplayName = $_.DisplayName
        Status = $_.Status.ToString()
        StartType = $_.StartType.ToString()
    }
})

$recentHotfixes = @(Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 8 | ForEach-Object {
    [ordered]@{
        HotFixID = $_.HotFixID
        Description = $_.Description
        InstalledOn = Format-DateValue $_.InstalledOn
    }
})

$pendingRebootKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
)
$pendingReboot = $false
foreach ($key in $pendingRebootKeys) {
    if ($key -like "*Session Manager") {
        $session = Get-ItemProperty -Path $key
        if ($session.PendingFileRenameOperations) { $pendingReboot = $true }
    } elseif (Test-Path $key) {
        $pendingReboot = $true
    }
}
if ($pendingReboot) { [void]$findings.Add("Windows appears to have a pending reboot. Restarting may complete updates and improve performance.") }

$policyPaths = @(
    "HKCU:\Software\Policies\Google\Chrome",
    "HKLM:\Software\Policies\Google\Chrome",
    "HKCU:\Software\Policies\Microsoft\Edge",
    "HKLM:\Software\Policies\Microsoft\Edge",
    "HKCU:\Software\Microsoft\Internet Explorer\Main"
)
$browserPolicies = @()
foreach ($path in $policyPaths) {
    $values = Get-RegistryValuesSafe $path
    if ($values) {
        $browserPolicies += [ordered]@{
            Path = Redact-Text $path
            Values = $values
        }
    }
}

$chromeExtensions = @()
$edgeExtensions = @()
if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $chromeExtensions = Redact-ExtensionIds (Get-BrowserExtensionIds (Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Extensions"))
    $edgeExtensions = Redact-ExtensionIds (Get-BrowserExtensionIds (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Extensions"))
}
if (($chromeExtensions.Count + $edgeExtensions.Count) -ge 30) { [void]$findings.Add("Many browser extensions detected. Disable suspicious or unused extensions if browser is slow or homepage is hijacked.") }

$tempFolders = @(
    (Get-FolderSizeQuick $env:TEMP),
    (Get-FolderSizeQuick "C:\Windows\Temp" 10000)
)
$tempTotalBytes = 0L
foreach ($temp in $tempFolders) { $tempTotalBytes += [int64]$temp.SizeBytes }
if ($tempTotalBytes -ge 5GB) { [void]$findings.Add("Temporary files are large: $(Format-Bytes $tempTotalBytes). Safe cleanup may help free space.") }

$report = [ordered]@{
    GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Tool = "PC Health Check"
    Mode = "Read-only diagnostic. No files or settings were changed."
    Privacy = [ordered]@{
        RedactIdentity = [bool]$RedactIdentity
        RedactedFields = @($redactedFields)
    }
    IsAdministrator = $isAdmin
    System = [ordered]@{
        ComputerName = Maybe-Redact $env:COMPUTERNAME
        UserName = Maybe-Redact $env:USERNAME
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        OS = $os.Caption
        OSVersion = $os.Version
        InstallDate = Format-DateValue $os.InstallDate
        LastBootUpTime = Format-DateValue $os.LastBootUpTime "yyyy-MM-dd HH:mm:ss"
        Uptime = $uptimeText
    }
    Performance = [ordered]@{
        CPUName = $cpu.Name
        CPULoadPercent = $cpuLoad
        TotalMemory = Format-Bytes $totalMemBytes
        FreeMemory = Format-Bytes $freeMemBytes
        UsedMemoryPercent = $usedMemPercent
        DiskBusyPercent = $diskBusy
    }
    Drives = $drives
    TopMemoryProcesses = $topMemoryProcesses
    StartupCommands = $startupCommands
    RunningAutoServicesTop80 = $autoServices
    AntivirusProducts = $antivirus
    Defender = $defender
    WindowsUpdateServices = $wuServices
    RecentHotfixes = $recentHotfixes
    PendingReboot = $pendingReboot
    BrowserPolicyOrHomepageKeys = $browserPolicies
    BrowserExtensions = [ordered]@{
        ChromeCount = $chromeExtensions.Count
        ChromeIds = $chromeExtensions
        EdgeCount = $edgeExtensions.Count
        EdgeIds = $edgeExtensions
    }
    TempFolders = $tempFolders
    Findings = @($findings)
}

Add-Line "PC Health Check Report"
Add-Line ("Generated at: {0}" -f $report.GeneratedAt)
Add-Line "Mode: Read-only diagnostic. No files or settings were changed."
Add-Line ("Identity redaction: {0}" -f $report.Privacy.RedactIdentity)
Add-Line ("Administrator: {0}" -f $isAdmin)

Add-Section "Quick Findings"
if ($findings.Count -eq 0) {
    Add-Line "No obvious high-risk performance issue was detected by the quick check."
} else {
    foreach ($finding in $findings) { Add-Line ("- {0}" -f $finding) }
}

Add-Section "System"
Add-Line ("Computer: {0}" -f $report.System.ComputerName)
Add-Line ("User: {0}" -f $report.System.UserName)
Add-Line ("Model: {0} {1}" -f $report.System.Manufacturer, $report.System.Model)
Add-Line ("OS: {0} ({1})" -f $report.System.OS, $report.System.OSVersion)
Add-Line ("Last boot: {0}" -f $report.System.LastBootUpTime)
Add-Line ("Uptime: {0}" -f $report.System.Uptime)

Add-Section "Performance"
Add-Line ("CPU: {0}" -f $report.Performance.CPUName)
Add-Line ("CPU load: {0}%" -f $report.Performance.CPULoadPercent)
Add-Line ("Memory: total {0}, free {1}, used {2}%" -f $report.Performance.TotalMemory, $report.Performance.FreeMemory, $report.Performance.UsedMemoryPercent)
if ($null -ne $report.Performance.DiskBusyPercent) {
    Add-Line ("Disk busy: {0}%" -f $report.Performance.DiskBusyPercent)
}

Add-Section "Drives"
foreach ($drive in $drives) {
    Add-Line ("{0} {1} | size {2} | free {3} ({4}%)" -f $drive.Drive, $drive.VolumeName, $drive.Size, $drive.Free, $drive.FreePercent)
}

Add-Section "Top Memory Processes"
foreach ($proc in $topMemoryProcesses) {
    Add-Line ("{0} (PID {1}) | memory {2} | CPU seconds {3}" -f $proc.Name, $proc.Id, $proc.Memory, $proc.CPUSeconds)
}

Add-Section "Startup Items"
Add-Line ("Count: {0}" -f $startupCommands.Count)
foreach ($item in $startupCommands) {
    Add-Line ("- {0} | {1} | user {2}" -f $item.Name, $item.Location, $item.User)
}

Add-Section "Antivirus"
if ($antivirus.Count -eq 0) {
    Add-Line "No antivirus product was reported by Windows Security Center."
} else {
    foreach ($av in $antivirus) {
        Add-Line ("- {0} | state {1}" -f $av.DisplayName, $av.ProductState)
    }
}
if ($defender) {
    Add-Line ("Defender real-time protection: {0}" -f $defender.RealTimeProtectionEnabled)
    Add-Line ("Defender signature updated: {0}" -f $defender.AntivirusSignatureLastUpdated)
}

Add-Section "Windows Update"
Add-Line ("Pending reboot: {0}" -f $pendingReboot)
foreach ($svc in $wuServices) {
    Add-Line ("- {0}: {1}, start type {2}" -f $svc.Name, $svc.Status, $svc.StartType)
}
Add-Line "Recent hotfixes:"
foreach ($hotfix in $recentHotfixes) {
    Add-Line ("- {0} | {1} | {2}" -f $hotfix.HotFixID, $hotfix.Description, $hotfix.InstalledOn)
}

Add-Section "Browser Check"
Add-Line ("Chrome extensions: {0}" -f $chromeExtensions.Count)
Add-Line ("Edge extensions: {0}" -f $edgeExtensions.Count)
if ($browserPolicies.Count -gt 0) {
    Add-Line "Browser policy/homepage registry values were found. Review JSON for details."
} else {
    Add-Line "No Chrome/Edge policy keys or IE homepage key values were found by this quick check."
}

Add-Section "Temporary Folders"
foreach ($temp in $tempFolders) {
    Add-Line ("{0} | exists {1} | files scanned {2} | size {3} | limited {4}" -f $temp.Path, $temp.Exists, $temp.FileCount, $temp.Size, $temp.Limited)
}

Add-Section "Next Step Suggestion"
Add-Line "Use this report to decide what should be checked next."
Add-Line "Do not delete files, disable startup items, uninstall apps, reset browsers, or change security settings until the device owner confirms."

$Lines | Set-Content -Path $txtPath -Encoding UTF8
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

if ($HtmlReport) {
    $htmlLines = New-Object System.Collections.Generic.List[string]
    [void]$htmlLines.Add("<!doctype html>")
    [void]$htmlLines.Add("<html lang=""en"">")
    [void]$htmlLines.Add("<head>")
    [void]$htmlLines.Add("<meta charset=""utf-8"">")
    [void]$htmlLines.Add("<meta name=""viewport"" content=""width=device-width, initial-scale=1"">")
    [void]$htmlLines.Add("<title>PC Health Check Report</title>")
    [void]$htmlLines.Add("<style>")
    [void]$htmlLines.Add("body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f6f8fa;color:#1f2328;line-height:1.45}")
    [void]$htmlLines.Add("main{max-width:980px;margin:0 auto;padding:24px}")
    [void]$htmlLines.Add("header{border-bottom:1px solid #d8dee4;margin-bottom:20px;padding-bottom:12px}")
    [void]$htmlLines.Add("h1{font-size:28px;margin:0 0 8px}h2{font-size:20px;margin:0 0 12px}")
    [void]$htmlLines.Add(".meta{color:#57606a}.card{background:#fff;border:1px solid #d8dee4;border-radius:6px;margin:16px 0;padding:16px}")
    [void]$htmlLines.Add(".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}")
    [void]$htmlLines.Add(".kv{border:1px solid #d8dee4;border-radius:6px;padding:10px}.label{color:#57606a;font-size:12px;text-transform:uppercase}.value{font-weight:600;margin-top:4px}")
    [void]$htmlLines.Add("table{border-collapse:collapse;width:100%;font-size:14px}th,td{border-bottom:1px solid #d8dee4;padding:8px;text-align:left;vertical-align:top}th{background:#f6f8fa}")
    [void]$htmlLines.Add(".finding{background:#fff8c5;border:1px solid #eac54f;border-radius:6px;margin:8px 0;padding:10px}.ok{background:#dafbe1;border-color:#4ac26b}")
    [void]$htmlLines.Add(".privacy{background:#ddf4ff;border-color:#54aeff}.small{font-size:13px;color:#57606a}")
    [void]$htmlLines.Add("</style>")
    [void]$htmlLines.Add("</head>")
    [void]$htmlLines.Add("<body><main>")
    [void]$htmlLines.Add("<header><h1>PC Health Check Report</h1><div class=""meta"">Generated at: $(Format-Html $report.GeneratedAt)</div><div class=""meta"">Mode: $(Format-Html $report.Mode)</div></header>")

    [void]$htmlLines.Add("<section class=""card privacy""><h2>Privacy</h2><div class=""grid"">")
    [void]$htmlLines.Add("<div class=""kv""><div class=""label"">Identity redaction</div><div class=""value"">$(Format-Html $report.Privacy.RedactIdentity)</div></div>")
    [void]$htmlLines.Add("<div class=""kv""><div class=""label"">Administrator</div><div class=""value"">$(Format-Html $report.IsAdministrator)</div></div>")
    [void]$htmlLines.Add("</div>")
    if ($report.Privacy.RedactedFields.Count -gt 0) {
        [void]$htmlLines.Add("<p class=""small"">Redacted fields: $(Format-Html (($report.Privacy.RedactedFields) -join ', '))</p>")
    }
    [void]$htmlLines.Add("</section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Quick Findings</h2>")
    if ($findings.Count -eq 0) {
        [void]$htmlLines.Add("<div class=""finding ok"">No obvious high-risk performance issue was detected by the quick check.</div>")
    } else {
        foreach ($finding in $findings) {
            [void]$htmlLines.Add("<div class=""finding"">$(Format-Html $finding)</div>")
        }
    }
    [void]$htmlLines.Add("</section>")

    [void]$htmlLines.Add("<section class=""card""><h2>System</h2><div class=""grid"">")
    foreach ($item in @(
        @("Computer", $report.System.ComputerName),
        @("User", $report.System.UserName),
        @("Model", ("{0} {1}" -f $report.System.Manufacturer, $report.System.Model)),
        @("OS", ("{0} ({1})" -f $report.System.OS, $report.System.OSVersion)),
        @("Last boot", $report.System.LastBootUpTime),
        @("Uptime", $report.System.Uptime)
    )) {
        [void]$htmlLines.Add("<div class=""kv""><div class=""label"">$(Format-Html $item[0])</div><div class=""value"">$(Format-Html $item[1])</div></div>")
    }
    [void]$htmlLines.Add("</div></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Performance</h2><div class=""grid"">")
    foreach ($item in @(
        @("CPU", $report.Performance.CPUName),
        @("CPU load", ("{0}%" -f $report.Performance.CPULoadPercent)),
        @("Memory", ("total {0}, free {1}, used {2}%" -f $report.Performance.TotalMemory, $report.Performance.FreeMemory, $report.Performance.UsedMemoryPercent)),
        @("Disk busy", ("{0}%" -f $report.Performance.DiskBusyPercent))
    )) {
        [void]$htmlLines.Add("<div class=""kv""><div class=""label"">$(Format-Html $item[0])</div><div class=""value"">$(Format-Html $item[1])</div></div>")
    }
    [void]$htmlLines.Add("</div></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Drives</h2><table><thead><tr><th>Drive</th><th>Volume</th><th>Size</th><th>Free</th><th>Free %</th></tr></thead><tbody>")
    foreach ($drive in $drives) {
        [void]$htmlLines.Add("<tr><td>$(Format-Html $drive.Drive)</td><td>$(Format-Html $drive.VolumeName)</td><td>$(Format-Html $drive.Size)</td><td>$(Format-Html $drive.Free)</td><td>$(Format-Html $drive.FreePercent)</td></tr>")
    }
    [void]$htmlLines.Add("</tbody></table></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Startup Items</h2><p>Count: $(Format-Html $startupCommands.Count)</p><table><thead><tr><th>Name</th><th>Location</th><th>User</th></tr></thead><tbody>")
    foreach ($item in $startupCommands) {
        [void]$htmlLines.Add("<tr><td>$(Format-Html $item.Name)</td><td>$(Format-Html $item.Location)</td><td>$(Format-Html $item.User)</td></tr>")
    }
    [void]$htmlLines.Add("</tbody></table></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Antivirus</h2><table><thead><tr><th>Name</th><th>State</th></tr></thead><tbody>")
    foreach ($av in $antivirus) {
        [void]$htmlLines.Add("<tr><td>$(Format-Html $av.DisplayName)</td><td>$(Format-Html $av.ProductState)</td></tr>")
    }
    [void]$htmlLines.Add("</tbody></table></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Windows Update</h2><p>Pending reboot: $(Format-Html $pendingReboot)</p><table><thead><tr><th>Service</th><th>Status</th><th>Start type</th></tr></thead><tbody>")
    foreach ($svc in $wuServices) {
        [void]$htmlLines.Add("<tr><td>$(Format-Html $svc.Name)</td><td>$(Format-Html $svc.Status)</td><td>$(Format-Html $svc.StartType)</td></tr>")
    }
    [void]$htmlLines.Add("</tbody></table></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Browser Check</h2><div class=""grid"">")
    [void]$htmlLines.Add("<div class=""kv""><div class=""label"">Chrome extensions</div><div class=""value"">$(Format-Html $chromeExtensions.Count)</div></div>")
    [void]$htmlLines.Add("<div class=""kv""><div class=""label"">Edge extensions</div><div class=""value"">$(Format-Html $edgeExtensions.Count)</div></div>")
    [void]$htmlLines.Add("</div></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Temporary Folders</h2><table><thead><tr><th>Path</th><th>Exists</th><th>Files scanned</th><th>Size</th><th>Limited</th></tr></thead><tbody>")
    foreach ($temp in $tempFolders) {
        [void]$htmlLines.Add("<tr><td>$(Format-Html $temp.Path)</td><td>$(Format-Html $temp.Exists)</td><td>$(Format-Html $temp.FileCount)</td><td>$(Format-Html $temp.Size)</td><td>$(Format-Html $temp.Limited)</td></tr>")
    }
    [void]$htmlLines.Add("</tbody></table></section>")

    [void]$htmlLines.Add("<section class=""card""><h2>Next Step Suggestion</h2><p>Use this report to decide what should be checked next.</p><p>Do not delete files, disable startup items, uninstall apps, reset browsers, or change security settings until the device owner confirms.</p></section>")
    [void]$htmlLines.Add("</main></body></html>")
    $htmlLines | Set-Content -Path $htmlPath -Encoding UTF8
}

Write-Host ""
Write-Host "PC Health Check completed."
Write-Host ("TXT report:  {0}" -f (Redact-Text $txtPath))
Write-Host ("JSON report: {0}" -f (Redact-Text $jsonPath))
if ($HtmlReport) {
    Write-Host ("HTML report: {0}" -f (Redact-Text $htmlPath))
}
Write-Host ""

if ($OpenReport -and (Test-Path $txtPath)) {
    if ($HtmlReport -and (Test-Path $htmlPath)) {
        Start-Process -FilePath $htmlPath
    } else {
        Start-Process -FilePath notepad.exe -ArgumentList ('"{0}"' -f $txtPath)
    }
}
