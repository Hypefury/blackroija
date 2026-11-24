# Agent instructions

A floating macOS window, written in Swift, that lists your Claude Code sessions and what they need. The README explains what it shows. All the code is in `blackroija.swift`, and there's no Xcode project.

## Build, check, restart

- Build with `./build.sh`. It compiles into a staging folder, so a failed build keeps the current app.
- Check a change with `--print` before restarting. It prints every section, the PR groups and the Control-Option-N order from your real sessions, then exits:
  ```bash
  "blackroija.app/Contents/MacOS/blackroija" --print
  ```
- Restart the running window after each build:
  ```bash
  pkill -x blackroija; sleep 1; open "blackroija.app"
  ```
  Without the `sleep`, `open` sometimes fails with error -600. Run it again if it does.
- You can't see the window or press its shortcut key. Say so in your report rather than implying you checked how it looks. Don't take full-screen screenshots to look for it: the window is often on another screen, and the capture records the user's mail and chats. Ask the user for a screenshot instead.
- To test a state the real sessions don't have (stuck, blocked), copy the app's source to a scratch folder, point `home` at a fake folder with made-up session files, and run `--print` there. Don't add test hooks to the app.

## Rules

- Read-only: never write to the desktop app's session files or conversation logs, and only read from GitHub through `gh`. The window's own cache is `~/Library/Application Support/blackroija/`.
- The window is for focus, so keep it quiet. No labels or tags, no red or bold text for messages, no long text in rows (a row's message shows only on hover), and no macOS notifications. Color goes on the dots and the PR status only. Before adding anything visible, ask whether it'll be read every time; if not, leave it out.
- "Finished" means archived. An idle, unarchived session always waits on the user, even when it says it's done.
- The PR list shows only the user's own PRs, plus teammates' PRs that an open session works on.
- Each requested change goes in its own commit. Push only when asked, to `master` with `git push origin HEAD:refs/heads/master`. The repo (`Hypefury/blackroija`) has no PR flow.
- The desktop app's files and `claude://` links aren't a public API. When something stops showing up, read the real files before changing the parsing.
