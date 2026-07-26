# Compound

An iOS workout tracker with routines, live set logging, a rest timer, progress charts, and a daily bodyweight and food log.

<p align="left">
  <img src="https://github.com/user-attachments/assets/bd7512be-580c-4574-a4b4-13434c1b8754" width="260" alt="Workout log">
  <img src="https://github.com/user-attachments/assets/3c6e7b63-aa70-4bff-9115-c7489fba8108" width="260" alt="Body">
  <img src="https://github.com/user-attachments/assets/848c91ae-2ea5-4eef-8ead-154ca3ae5fcc" width="260" alt="Stats">
</p>

## Features

- Build routines from a 24-exercise starter library, or add your own from any picker
- Live workouts with a session timer and grey "ghost" hints of last time's reps and weight
- Manual rest timer with presets, sound, haptics, and a notification if you leave the app
- Minimize a workout to a mini bar, or follow it on the Lock Screen and Dynamic Island
- Resumes an interrupted session after a crash or force-quit
- Workout log grouped by month, fully editable, with save-as-routine
- Stats for streaks and training frequency, plus lift progression by top set, est. 1RM, or volume
- Body tab for bodyweight, calories, protein, and a paste-friendly food log
- lb/kg units that convert every saved weight, light/dark themes, JSON export
- Offline: no account, no network, everything local in SwiftData

## Requirements

- iPhone running iOS 17.0 or later
- Xcode 16.0 or later (for development) — the project uses file-system synchronized groups

## Installation

1. Clone and open `Compound.xcodeproj` in Xcode
2. Set your own bundle identifier and signing team on both the **Compound** and **CompoundWidgets** targets
3. Build and run
4. Create a routine, start a workout, and log your first set

## Configuration

### Demo Data (DEBUG)

Seeds a push/pull/legs block over the last seven weeks, three routines, and a month of body entries.

From the app: **Profile → Developer → Seed Demo Data / Wipe All Data**.

By launch argument:

```
-seedDemoData
-wipeData
```

```
xcrun simctl launch booted Oriented.Compound -seedDemoData
```

In Xcode's scheme editor each argument must be its own row — `-seedDemoData YES` on one row matches nothing and silently does nothing. Seeding is idempotent, so leaving it on is safe. None of this ships in Release.

### Live Activity

1. Start a workout from **Routines**
2. Lock the device or simulator (⌘L) — the activity shows the rest countdown, or elapsed time when not resting
3. Tap it to reopen and maximize the workout

Live Activities run in the Simulator; the expanded Dynamic Island needs a physical device to long-press.

## Tests

```
xcodebuild test -project Compound.xcodeproj -scheme Compound \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Acknowledgments

- Built with SwiftUI, SwiftData, and Swift Charts
- Live Activity powered by ActivityKit and WidgetKit
