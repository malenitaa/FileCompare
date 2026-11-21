# Security

FileCompare is a small offline desktop app. This document describes its
actual attack surface, based on the code in this repository — not a generic
policy template.

## What it touches

| Path | Access | Written by |
|------|--------|-----------|
| The files you explicitly open (open panel, drag & drop) | read | — |
| The files you explicitly save (save panel, or "Save panel" back to its source) | write | The app, only on your action |
| `~/Library/Preferences/io.github.malenitaa.FileCompare.plist` | read + write | macOS UserDefaults, on the app's behalf |

That is the complete list. The preferences file contains exactly three
values: the paths of the last two files you opened (so they reload on next
launch — see `RecentFilesStore.swift`) and the language setting
(`L10n.swift`). Nothing else is ever read or written: no caches, no
containers, no saved-state files (verified empirically after running the
app).

## What it never touches

- **Network.** There is no networking code anywhere in the app — no
  `URLSession`, no sockets, nothing. The diff runs entirely on your machine.
- **The rest of your disk.** Files are only ever read through the open
  panel, drag & drop, or the two remembered recent paths — never by
  scanning or enumerating directories.
- **Credentials, Keychain, clipboard reads, microphone, camera.** Never
  accessed. (The "Copy list" button in Sets mode *writes* to the clipboard,
  on your click; nothing ever reads it.)
- **Telemetry or analytics.** None. There are no third-party dependencies at
  all — the app is plain Swift/SwiftUI/AppKit.

## Untrusted input

The only external input is the files you open, and they are treated as
untrusted bytes:

- `FileLoader.decode` validates encodings instead of guessing blindly:
  UTF-16 is only accepted with a real BOM or, without one, when its NUL
  bytes fall on one side of every byte pair (otherwise Latin-1 text silently
  mis-decodes); any other file with a NUL byte is rejected before UTF-8 is
  tried, since NUL is valid UTF-8; UTF-8 comes next (self-validating), and
  anything else that looks binary (heavy control-byte density) is rejected
  with an error instead of being force-decoded into garbage. The reasoning is
  documented line by line in `FileCompare/Support/FileLoader.swift`.
- Large files don't hang the UI: word-level highlighting is skipped past a
  size/line threshold (`DiffOptions.swift`), and diffs compute on a
  background task that gets cancelled when a newer edit supersedes it.
- The remembered recent paths are checked for existence before loading, and
  a file that fails to load just shows an error banner.

## What is less tested

- The **Intel (x86_64)** half of the universal binary gets less manual
  testing — the app is developed and tested on Apple Silicon.
- The app is **not App-Sandboxed** (it's a developer tool that needs to open
  arbitrary text files the user picks). It ships with hardened runtime
  enabled and is unsigned (no paid Apple developer certificate) — see the
  README for the standard Gatekeeper first-open step.

## Reporting

Found something? Open an issue on
[GitHub Issues](https://github.com/malenitaa/FileCompare/issues) or send a
fix directly. There is no sensitive data at stake in this app, so public
issues are fine.
