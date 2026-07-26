# Project Notes

## macOS Cursor Agent Worker Service

- `cursor-agent` is installed at `~/.local/bin/cursor-agent` and is already authenticated.
- The LaunchAgent at `~/Library/LaunchAgents/com.cursor.cursor-agent-worker.plist` loads successfully with `launchctl load`.
- On macOS 15 (Darwin 27), the service may fail to start with `Operation not permitted` because the `cursor-agent` files have `com.apple.provenance` attributes and macOS may never show an Allow prompt for `launchd`.
- Workaround: run the bundled `node` directly from the LaunchAgent instead of the `cursor-agent` shell script. Use a `sh -c` `ProgramArguments` entry that resolves the version at runtime via the `cursor-agent` symlink, so it survives updates. Set `EnvironmentVariables` for `CURSOR_INVOKED_AS` and `NODE_COMPILE_CACHE`.
- Once running, the worker URL will appear in `~/Library/Logs/cursor-agent-worker.log`.
