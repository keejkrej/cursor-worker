if (-not $env:CURSOR_INVOKED_AS) {
    $env:CURSOR_INVOKED_AS = 'cursor-agent'
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

if (-not $env:NODE_COMPILE_CACHE) {
    $env:NODE_COMPILE_CACHE = "$env:LOCALAPPDATA\cursor-compile-cache"
}

function Parse-VersionString {
    param (
        [string]$versionString
    )

    $datePart = $versionString.Split('-')[0]
    $parts = $datePart.Split('.')

    if ($parts.Length -ne 3) {
        throw "Invalid version format. Expected format: YYYY.MM.DD-commit"
    }

    $year = $parts[0]
    $month = $parts[1].PadLeft(2, '0')
    $day = $parts[2].PadLeft(2, '0')

    return [int]($year + $month + $day)
}

if (Test-Path "$scriptPath\node.exe") {
    $nodePath = "$scriptPath\node.exe"
    $indexPath = "$scriptPath\index.js"
} else {
    $versionDir = Get-ChildItem -Path "$scriptPath\versions" -Directory |
        Where-Object {
            $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}(-\d{2}-\d{2}-\d{2})?-[a-f0-9]+$'
        } |
        Sort-Object { Parse-VersionString $_.Name } -Descending |
        Select-Object -First 1

    if (-not $versionDir) {
        throw "No version directories found in $scriptPath"
    }

    $nodePath = "$scriptPath\versions\$($versionDir.Name)\node.exe"
    $indexPath = "$scriptPath\versions\$($versionDir.Name)\index.js"
}

Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public class NativeLauncher {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CreateProcessW(
        string lpApplicationName,
        StringBuilder lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetExitCodeProcess(IntPtr hProcess, out uint lpExitCode);

    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO {
        public uint cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }
}
'@

$cmd = '"' + $nodePath + '" "' + $indexPath + '"'
if ($args) {
    $cmd += " " + ($args -join " ")
}

$si = New-Object NativeLauncher+STARTUPINFO
$si.cb = [UInt32][System.Runtime.InteropServices.Marshal]::SizeOf($si)

$pi = New-Object NativeLauncher+PROCESS_INFORMATION

$CREATE_DETACHED = [UInt32]0x00000008
$ok = [NativeLauncher]::CreateProcessW($nodePath, [System.Text.StringBuilder]::new($cmd), [IntPtr]::Zero, [IntPtr]::Zero, $false, $CREATE_DETACHED, [IntPtr]::Zero, $env:USERPROFILE, [ref]$si, [ref]$pi)
if (-not $ok) { throw (New-Object System.ComponentModel.Win32Exception ([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())) }

$exitCode = [UInt32]0
[void][NativeLauncher]::WaitForSingleObject($pi.hProcess, [UInt32]::MaxValue)
[void][NativeLauncher]::GetExitCodeProcess($pi.hProcess, [ref]$exitCode)
[void][NativeLauncher]::CloseHandle($pi.hProcess)
[void][NativeLauncher]::CloseHandle($pi.hThread)
exit $exitCode
