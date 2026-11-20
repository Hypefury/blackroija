# Session Status

A small floating Mac window that lists your open Claude Code sessions (the Code tab of the Claude desktop app) for the Hypefury repos. It shows which sessions are working, which need you, and which are stuck, plus your open PRs. Work in one session at a time and jump to the next one from here.

It only reads files on your Mac and GitHub. It never sends anything to a session or changes a PR.

## What you see

Sessions are sorted into sections, and grouped by app (Web app, Mobile, Website) inside each section:

- **Stuck** (orange): the session stopped mid-turn (for example after a connection error), or it's idle while one of its PRs has failing checks or conflicts. A short line says which.
- **Needs you**: the session is idle and waiting on you. A red dot means it's blocked until you answer: a question card, a plan to approve, or something the session marked as blocking. These come first, oldest first. A session that says it's done stays here until you archive it.
- **Working** (green dot): Claude is mid-turn, or a helper agent or background job it started is still running.
- **Waiting** (dimmed): idle, but only waiting on CI or another PR.
- Sessions idle for over a day are only counted, at the bottom.

Each row shows the title, how long it's been idle and all its open PRs. A PR marked "(failing)" has failing checks, and one marked "(conflicts)" has merge conflicts. Click a row to open the session, or click a PR number to open it on GitHub. Hover over a row to see what the session is asking for.

At the bottom, **PRs** lists your own open PRs, plus teammates' PRs that an open session works on, grouped by app. Each one shows a colored dot (red for failing checks, orange for conflicts, green for passing, gray for a draft, a stacked PR or pending checks), its number and its title. Click "PRs" to fold the list.

**Control-Option-N**, from any app, opens the next session that needs you: stuck sessions first, then blocked ones, then the rest. Press it again to move on. The last session it opened is shaded in the window.

Right-click the window for Refresh, the same "next session" action, and Quit.

## Requirements

- macOS 14 or later.
- Swift: install the Xcode command line tools with `xcode-select --install`.
- The Claude desktop app, with sessions in the Code tab.
- The GitHub CLI (`gh`), installed with Homebrew and logged in (`gh auth login`). It's used read-only, once a minute. Without it, the window still works but shows no PRs.
- Optional: the `claude` command, logged in. It's used only when the desktop app hasn't saved a status for a session's latest reply. Haiku then reads that reply once to tell whether it waits on you, and the answer is cached in `~/Library/Application Support/SessionStatus/grades.json`.

## Install

```bash
git clone git@github.com:Hypefury/session-status.git ~/workspace/session-status
```

```bash
cd ~/workspace/session-status && ./build.sh && open "Session Status.app"
```

To have it open at login:

```bash
cd ~/workspace/session-status && ./install-login-item.sh
```

After changing the code, rebuild and restart it:

```bash
cd ~/workspace/session-status && ./build.sh && pkill -x SessionStatus; sleep 1; open "Session Status.app"
```

## Setup for your own folders

The window shows sessions whose folder belongs to one of these repos. It finds them by their git folder, so worktrees count too. Edit `projects` at the top of `SessionStatus.swift` if your clones live elsewhere:

```swift
let projects: [String: String] = [
    "\(home)/workspace/hypefury-v2/.git": "Web app",
    "\(home)/workspace/hypefury-website/.git": "Website",
    "\(home)/workspace/hypefury-v2-mobile/.git": "Mobile",
]
```

`repos` maps each label to its GitHub repo, for the PR list. Your GitHub login decides which PRs are "yours".

## Checking it from the terminal

`--print` prints the same sections, the PR groups and the order Control-Option-N follows, then exits:

```bash
cd ~/workspace/session-status && "Session Status.app/Contents/MacOS/SessionStatus" --print
```

## How it works

- Sessions: `~/Library/Application Support/Claude/claude-code-sessions/*/*/local_*.json`, one file per session. Each one holds the title, folder, PRs, last activity, whether it's archived, and the status the app saves after each turn. Archived sessions are skipped.
- Conversation logs: `~/.claude/projects/*/<session>.jsonl`. They tell whether Claude is mid-turn, whether a question card or plan is unanswered, whether background work is still running, and whether the turn ended on an error.
- Everything refreshes every 5 seconds, and PRs every 60 seconds.
- The window floats above other windows, stays on the desktop you put it on, and keeps running when closed. Quit it from the right-click menu.
- Opening a session uses the `claude://claude.ai/epitaxy/<session id>` link.

These files belong to the Claude desktop app and aren't a public API, so an app update can break the window. When that happens, `--print` is the quickest way to see what it reads.
