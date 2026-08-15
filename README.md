# Notch Companion

A tiny macOS app that puts a pixel crab in your MacBook notch and reacts to Claude Code lifecycle events.

The crab is a 14×8 pixel-art mascot inspired by Claude Code's boot logo, drawn as SwiftUI rectangles with terminal-cell aspect ratio (3px wide × 5px tall pixels).

## What it does

Shows a Dynamic-Island-style black pill hanging from the top-center of the screen, positioned so its content sits *below* the physical MacBook notch cutout. Reacts to five states:

| State | What you see |
|---|---|
| **idle** | Compact pill, hidden behind the notch |
| **thinking** | Pill expands, crab scuttles side-to-side with a small bob, "Thinking..." label with pulsing pixel dots |
| **waiting** | Crab waves a claw in short bursts every ~2s, "Your turn" label |
| **done** | Pill glows green, crab pops with a bounce, ✓ + "Ready", auto-returns to idle after 2s |
| **error** | Pill flashes red, crab wobbles, ⚠️ + "Error", auto-returns to idle after 2s |

State changes come from the contents of `/tmp/claude-notch-state`. Anything can write to that file — Claude Code hooks, a script, `echo`, curl. The app watches the file with `DispatchSource` and re-renders on every change.

The menu bar shows a small black pixel crab with white eyes. Click it to manually cycle any state or quit.

## Build & run

Needs Xcode Command Line Tools (`xcode-select --install` if you don't have them). macOS 13+.

From this folder:

```bash
swift run
```

First run compiles in ~30 seconds. Later runs are near-instant.

**Stop it:** `Ctrl+C` in the same terminal, or click the dark crab in the menu bar → **Quit**.

**Keep it running after closing the terminal:**

```bash
nohup swift run > /tmp/notch.log 2>&1 &
```

**Build a release binary and launch it directly** (no swift run needed each time):

```bash
swift build -c release
./.build/release/NotchCompanion
```

## Wire it to Claude Code

Add these hooks to `~/.claude/settings.local.json` (or `settings.json`). If you already have a `hooks` block, merge — don't replace:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "echo thinking > /tmp/claude-notch-state" }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          { "type": "command", "command": "echo waiting > /tmp/claude-notch-state" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "echo thinking > /tmp/claude-notch-state" }
        ]
      }
    ],
    "PermissionDenied": [
      {
        "hooks": [
          { "type": "command", "command": "echo thinking > /tmp/claude-notch-state" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "echo done > /tmp/claude-notch-state" }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          { "type": "command", "command": "echo error > /tmp/claude-notch-state" }
        ]
      }
    ]
  }
}
```

**Why so many hooks?** `UserPromptSubmit` fires when you send Claude a message. `PermissionRequest` fires when Claude wants approval to run a tool (bash, edit, etc.) — that's your "your turn" moment. `PreToolUse` fires the instant a tool actually runs (after you approve), so the notch flips back to thinking. `PermissionDenied` catches the case where you deny — Claude keeps working, so back to thinking. `Stop` and `StopFailure` handle the end of a turn.

**After adding:** in any active Claude Code session, type `/hooks` and hit Return (then dismiss the dialog). That reloads the settings without restarting.

**Test it without Claude Code:**

```bash
echo thinking > /tmp/claude-notch-state
echo waiting  > /tmp/claude-notch-state
echo done     > /tmp/claude-notch-state
echo error    > /tmp/claude-notch-state
echo idle     > /tmp/claude-notch-state
```

The notch should react to each.

## Known v0 limits

- **Single screen only** — uses `NSScreen.main`. If you plug in an external display or change your primary screen, restart the app.
- **No auto-launch on login** — add via System Settings → General → Login Items & Extensions → click **+** under "Open at Login" and pick `NotchCompanion` from `~/Desktop/notch-crab/.build/release/` (needs `swift build -c release` first).
- **Menu bar icon is not template** — the dark crab reads well against a light menu bar but will disappear against a dark menu bar. Set `image.isTemplate = true` in `main.swift` if you want macOS to auto-invert it (loses the color).
- **Designed for MacBooks with a physical notch** — content sits ~32pt below the top of the screen to clear the notch cutout. Works fine on notch-less Macs; it just looks like a floating pill instead of one hanging from a cutout.

## Files

- `Package.swift` — Swift Package manifest, macOS 13+, one executable target.
- `Sources/NotchCompanion/main.swift` — everything else in one file (~350 lines): pixel crab, state controller, notch view + window, file watcher, app delegate.
- `.gitignore` — excludes `.build/`, `.swiftpm/`, `.DS_Store`, and Xcode cruft.
