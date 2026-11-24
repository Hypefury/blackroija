# Agent instructions

A floating macOS window, written in Swift, that lists your Claude Code sessions and what they need. The README explains what it shows. All the code is in `blackroija.swift`, and there's no Xcode project.

## Build, check, restart

- Build with `./build.sh`. It compiles into a staging folder, so a failed build keeps the current app.
- Restart the running window after each build:
  ```bash
  pkill -x blackroija; sleep 1; open "blackroija.app"
  ```
  Without the `sleep`, `open` sometimes fails with error -600. Run it again if it does.
- You can't see the window. Say so in your report rather than implying you checked how it looks. Don't take full-screen screenshots to look for it: the window is often on another screen, and the capture records the user's mail and chats. Ask the user for a screenshot instead.

## Rules

- Read-only: never write to the desktop app's session files or conversation logs, and only read from GitHub through `gh`. The one thing the app runs besides `gh` is `brew upgrade`, from the Update button, and only in a Homebrew install. The window's own cache is `~/Library/Application Support/blackroija/`.
- The window is for focus, so keep it quiet. No labels or tags, no red or bold text for messages, no long text in rows, and no macOS notifications. Color goes on the dots and the PR status only. Before adding anything visible, ask whether it'll be read every time; if not, leave it out.
- "Finished" means archived. An idle, unarchived session always waits on the user, even when it says it's done.
- The PR list shows only open PRs that a session works on, and only sessions that are working or active within the last week (`isFresh`, the same rule as the session list). No PR without a session.
- The repo is public, so nothing private goes in it. README screenshots and examples use made-up sessions and PRs, never real session titles, repo names or PR numbers. Make them from a scratch copy of the app pointed at a fake `home`.
- Each requested change goes in its own commit. Push only when asked, to `master` with `git push origin HEAD:refs/heads/master`. The repo (`Hypefury/blackroija`) has no PR flow.
- The desktop app's files and `claude://` links aren't a public API. When something stops showing up, read the real files before changing the parsing.

## Releasing

- A release is a `vX.Y.Z` tag on `master`. Pushing it is all it takes: a workflow here tells the Homebrew tap (`Hypefury/homebrew-tap`) at once, so its formula follows within a minute (the tap also checks every hour, as a backup), and the app's Update button offers the new version to Homebrew installs. The workflow needs the repo secret `TAP_TOKEN`; if it's missing or expired, the hourly check still catches up.
- When your work is done and on `master` (or ready to go there), suggest a release and say which kind. A patch, the `z` in `x.y.z` (`0.2.2` to `0.2.3`), is for fixes and changes nobody sees. A minor, the `y` (`0.2.2` to `0.3.0`), is for something new the user sees or does. Say why in one sentence. Leave the `x` alone unless the user asks.
- Only tag when asked. Tag the commit that's on `origin/master`, push with `git push origin refs/tags/vX.Y.Z`, and check the tap's formula points at the new tag afterwards.
- `./build.sh` takes the version from the `VERSION` environment variable (default `0.1`), so a build from a clone only shows the right number if you set it.
