#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$nssm = Join-Path $env:USERPROFILE 'nssm\nssm-2.24-101-g897c7ad\win64\nssm.exe'
$serviceName = 'CursorAgentWorker'

if (-not (Test-Path $nssm)) {
    throw "nssm.exe not found at $nssm. Download and extract nssm to $env:USERPROFILE\nssm."
}

$src = Join-Path $PSScriptRoot 'worker-hidden.ps1'
$dst = Join-Path $env:LOCALAPPDATA 'cursor-agent\worker-hidden.ps1'
if (-not (Test-Path $src)) {
    throw "worker-hidden.ps1 not found next to this script."
}
Copy-Item -Path $src -Destination $dst -Force
Write-Host "Copied worker-hidden.ps1 to $dst"

Unregister-ScheduledTask -TaskName 'Cursor Agent Worker' -Confirm:$false -ErrorAction SilentlyContinue

$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing $serviceName service..."
    & $nssm remove $serviceName confirm
}

$account = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { ".\$env:USERNAME" }
Write-Host "This service will run as: $account"
$secure = Read-Host "Enter the Windows password for $account" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)

try {
    Write-Host "Installing $serviceName..."
    & $nssm install $serviceName "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$dst`" worker start"

    & $nssm set $serviceName AppDirectory $env:USERPROFILE
    & $nssm set $serviceName ObjectName $account
    & $nssm set $serviceName Password $password
    & $nssm set $serviceName Start SERVICE_AUTO_START

    $logs = Join-Path $env:LOCALAPPDATA 'cursor-agent\logs'
    if (-not (Test-Path $logs)) { New-Item -ItemType Directory -Force -Path $logs | Out-Null }
    & $nssm set $serviceName AppStdout (Join-Path $logs 'nssm-stdout.log')
    & $nssm set $serviceName AppStderr (Join-Path $logs 'nssm-stderr.log')

    Write-Host "Starting $serviceName..."
    & $nssm start $serviceName

    Write-Host "$serviceName installed and started."
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    $password = $null
}
