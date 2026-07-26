# Project Notes

## macOS Cursor Agent Worker Service

- `cursor-agent` is installed at `~/.local/bin/cursor-agent` and is already authenticated.
- The LaunchAgent at `~/Library/LaunchAgents/com.cursor.cursor-agent-worker.plist` loads successfully with `launchctl load`.
- On macOS 15 (Darwin 27), the service may fail to start with `Operation not permitted` because the `cursor-agent` files have `com.apple.provenance` attributes and are not code-signed.
- Running `cursor-agent worker debug` directly from a Terminal session works and confirms the account identity.
- To finish the install, allow `cursor-agent` in **System Settings > Privacy & Security > Security** after the service attempts to start, or run the worker once from a GUI Terminal to trigger the allow prompt.
- Once running, the worker URL will appear in `~/Library/Logs/cursor-agent-worker.log`.
