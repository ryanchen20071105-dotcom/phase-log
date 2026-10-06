# Phase Log · 阶段日志

English | [中文](README.md)

Track your growth as **areas → phases → days**. A small macOS app with an Apple-style interface; all data stays on your Mac.

> The interface is in Chinese.

![Overview](docs/screenshots/overview.png)

## Why

A to-do list tells you what to do today, but not where you have been heading lately.

Phase Log splits your life into a few **areas** — say, research, fitness and English. Each area runs one **phase** at a time, such as "literature review → experiment design → writing". Every day you jot down what you did in that phase; when a phase ends you write a short summary and start the next one. Over time the calendar fills with colored phases that show the path you have taken.

## Features

- **Areas and phases** — each area has one active phase, showing how many days it has run and how many entries it has. End the current phase whenever you like, write a summary, carry unfinished goals over, and start the next one.
- **Daily entries** — write what you did today in the current phase; it saves automatically. You can also fill in past days.
- **Two kinds of goals** — area goals are long-term and stay across phases; phase goals (optional) belong to the current phase. Every goal records when it was created and when it was completed.
- **Full-screen calendar** — each phase is a colored bar spanning its dates; days with entries get colored dots and days with completed goals get a ✓. Click any day to read or fill in that day's entries and see the goals completed that day and the goals open at the time.
- **To-dos** — quick add inspired by TickTick. Typing "明天交周报" (hand in the weekly report tomorrow), "周五组会" (group meeting on Friday), "10月20日体检" or "3天后还书" (return the book in 3 days) recognizes the date automatically; click × if it guessed wrong.
- **Reflections** — write down your thoughts for a period of time. Starting a new one archives the old one, which you can read again any time.
- **Smooth transitions** — click "查看领域" (view area) in the calendar and the area's name flies into the big title of the detail page, then flies back when you return.
- **Native Mac app** — its own window and Dock icon, follows system dark mode, and saves before quitting.
- **Local only** — your data is a single `data.json` file, backed up automatically on the first save each day. No account, no network.

| Calendar | Area detail |
|---|---|
| ![Calendar](docs/screenshots/calendar.png) | ![Area detail](docs/screenshots/domain.png) |

![Dark mode](docs/screenshots/overview-dark.png)

## Install

Requires macOS 12 or later (tested on macOS 26) and the Xcode Command Line Tools (which provide the Swift compiler and Python 3).

```bash
xcode-select --install          # skip if already installed
git clone https://github.com/ryanchen20071105-dotcom/phase-log.git
cd phase-log
./app/build.sh                  # builds 阶段日志.app
open 阶段日志.app
```

Then drag `阶段日志.app` to the Dock to open it with one click. If the project lives in Desktop or Documents, macOS will ask for permission to access that folder the first time — click Allow.

You can also skip building and use a browser:

```bash
python3 server.py               # opens http://127.0.0.1:8790 automatically
```

## Tips

| Shortcut | Action |
|---|---|
| ⌘1 / ⌘2 | Overview / Calendar |
| ⌘N | New area |
| ⌘+ / ⌘− / ⌘0 | Zoom in / out / actual size |
| ⌘R | Reload |
| Esc | Close the calendar side panel |

- After deleting a goal, entry or to-do, an "撤销" (undo) button appears at the bottom for 6 seconds.
- Swipe right with two fingers on the trackpad to go back.

## Data

- Everything is stored in `data.json` inside the project folder. It is listed in `.gitignore`, so it is never committed.
- On the first save each day, the previous file is copied to `backups/data-<date>.json`.
- To move to another Mac, just copy `data.json`.

## Project layout

```
index.html        The whole interface and logic (a single file, no dependencies)
server.py         Local server: serves the page, reads/writes data.json, daily backups (Python standard library only)
app/main.swift    Native app: a WKWebView window that starts and stops the local server
app/icon.swift    Draws the app icon in code
app/Info.plist    App metadata
app/build.sh      Builds and assembles 阶段日志.app
启动.command       Double-click to open the app (falls back to the browser version if the app isn't built)
```

## Development

- After editing `index.html`, press ⌘R in the app to see the change; after editing the Swift code, run `./app/build.sh` again.
- Keep your real data out of tests by using another port and data file:

  ```bash
  PORT=8799 DATA_FILE=/tmp/test.json NO_BROWSER=1 python3 server.py
  ```

- The app also reads a few environment variables for testing: `PHASELOG_PORT`, `PHASELOG_DATA`, `PHASELOG_TEST_JS`, `PHASELOG_SNAPSHOT` and `PHASELOG_QUIT` — see `app/main.swift`.

## License

[MIT](LICENSE)
