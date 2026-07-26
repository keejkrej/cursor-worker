# Cursor Agent Worker Deployment

Deploy a persistent Cursor Agent private-cloud worker on Linux, macOS, or Windows.

## 1. Install Cursor CLI

### Linux / macOS / WSL

```bash
curl https://cursor.com/install -fsS | bash
```

Make sure `~/.local/bin` is on your PATH (the installer usually adds it). Verify:

```bash
cursor-agent --version
```

The command is also available as `agent`.

### Windows (native PowerShell)

```powershell
irm 'https://cursor.com/install?win32=true' | iex
```

Reopen PowerShell and verify:

```powershell
agent --version
```

The binaries are installed to `%LOCALAPPDATA%\cursor-agent` and that directory is added to your user PATH.

## 2. Log in

Use the same Cursor account you use on your remote machine.

```bash
cursor-agent login
```

## 3. Optional: run a preflight check

```bash
cursor-agent worker debug
```

You should see your identity and a visibility probe listing this worker.

## 4. Run the worker automatically

### Linux (systemd user service)

Create `~/.config/systemd/user/cursor-agent-worker.service` with these contents:

```systemd
[Unit]
Description=Cursor Agent private cloud worker
After=network.target

[Service]
Type=exec
WorkingDirectory=~
ExecStart=%h/.local/bin/cursor-agent worker start
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Then:

```bash
systemctl --user daemon-reload
systemctl --user enable --now cursor-agent-worker.service
```

Check status:

```bash
systemctl --user status cursor-agent-worker.service
```

### macOS (launchd user agent)

Create `~/Library/LaunchAgents/com.cursor.cursor-agent-worker.plist`, replacing `YOUR_USERNAME` with your macOS username:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cursor.cursor-agent-worker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/.local/bin/cursor-agent</string>
        <string>worker</string>
        <string>start</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/cursor-agent-worker.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/cursor-agent-worker.log</string>
</dict>
</plist>
```

Load it:

```bash
mkdir -p ~/Library/Logs
launchctl load ~/Library/LaunchAgents/com.cursor.cursor-agent-worker.plist
```

### Windows (Task Scheduler)

Open PowerShell as your normal user and run:

```powershell
$exe = Join-Path $env:LOCALAPPDATA "cursor-agent\cursor-agent.exe"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command & `"$exe`" worker start" -WorkingDirectory $env:USERPROFILE
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartOnDemand -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "Cursor Agent Worker" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
Start-ScheduledTask -TaskName "Cursor Agent Worker"
```

Check Task Scheduler for status.

## 5. Access the worker

Once running, the worker URL is in the logs, for example:

```
https://cursor.com/agents#workerId=...
```

Open that URL in a browser to chat with the worker.

## 6. Updates

The CLI auto-updates by default. After an update you may need to restart the worker.

Linux:

```bash
systemctl --user restart cursor-agent-worker.service
```

macOS:

```bash
launchctl unload ~/Library/LaunchAgents/com.cursor.cursor-agent-worker.plist
launchctl load ~/Library/LaunchAgents/com.cursor.cursor-agent-worker.plist
```

Windows:

Use Task Scheduler to restart the task.

## Notes

- If you want repo-based matching in the Cursor desktop app, start the worker from that git repo or add `--worker-dir /path/to/repo` to the start command.
- The command is available as both `agent` and `cursor-agent` on most platforms. These instructions use `cursor-agent` for consistency.
