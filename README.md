# Rancage

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-blue?logo=swift&logoColor=white)
![IOKit](https://img.shields.io/badge/IOKit-SMC-green?logo=apple&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Intel%20Mac-lightgrey?logo=intel&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)

Native macOS menu bar app — fan monitor, temperature, resource usage, dan sleep prevention dalam satu tool ringan.

Swift + SwiftUI. No Electron. No dependencies. Cuma IOKit + AppKit.

![Screenshot](assets/ss1.png)

## Features

- **Fan Speed** — Live RPM + min/max range dari hardware via SMC
- **CPU Temperature** — Langsung dari SMC sensor
- **GPU Temperature** — Intel UHD GPU sensor
- **CPU Usage** — Delta-based (sama kayak Activity Monitor)
- **RAM Usage** — Active + Wired + Compressed
- **Stay Awake** — Dua mode: Prevent Sleep (system only) atau Prevent Sleep + Lock (display stays on)
- **History Graphs** — Timeline visual tiap metric, cached di disk
- **Menu Bar** — Configurable: icon only, text only, atau both. Fixed-width biar ngga geser-geser
- **Dashboard + Settings** — Satu window dengan fixed sidebar
- **Alerts** — Notifikasi saat CPU/GPU temp atau RAM exceed threshold
- **Persistent State** — Settings & caffeine state persist across relaunch

## Requirements

- macOS 14 (Sonoma) or later
- Intel Mac (tested on MacBook Pro 13" 2019)
- Swift 5.9+

## Build & Run

```bash
# Build dan create .app bundle
./scripts/bundle.sh

# Jalanin app
open build/Rancage.app

# Install ke Applications
cp -r build/Rancage.app /Applications/
```

Atau langsung:

```bash
swift build
swift run
```

## Xcode

Buka `Package.swift` langsung di Xcode — standard Swift Package Manager project. No `.xcodeproj` needed.

## Configuration

Settings disimpan sebagai JSON:

```
~/.config/rancage/settings.json
```

History cache (untuk graphs):

```
~/.cache/rancage/history.json
```

### Settings Options

| Setting | Default | Description |
|---------|---------|-------------|
| showCPUInMenuBar | true | Tampilkan CPU % di menu bar |
| showCPUTempInMenuBar | true | Tampilkan suhu CPU |
| showRAMInMenuBar | true | Tampilkan RAM % |
| showFanInMenuBar | true | Tampilkan fan RPM |
| showCaffeineInMenuBar | true | Tampilkan icon caffeine saat aktif |
| menuBarStyle | both | `icon`, `text`, atau `both` |
| showDockIcon | false | Tampilkan icon di Dock |
| refreshInterval | 1.0 | Interval refresh dalam detik (1, 2, 3, 5, 10) |
| stayAwake | false | State caffeine persist across relaunch |
| caffeineMode | preventSleep | `preventSleep` atau `preventDisplaySleep` |
| alertsEnabled | true | Aktifkan notifikasi threshold |
| tempAlertThreshold | 90 | Alert saat temp ≥ value (°C) |
| ramAlertThreshold | 90 | Alert saat RAM ≥ value (%) |

## Project Structure

```
rancage/
├── Package.swift
├── assets/
│   ├── logo.png                  ← App icon (rounded, scaled)
│   ├── icon_raw.png              ← Source icon (from design tool)
│   └── icons/                    ← SVG reference untuk menu bar icons
│       ├── cpu.svg
│       ├── thermometer.svg
│       ├── memory.svg
│       ├── fan.svg
│       └── caffeine.svg
├── scripts/
│   ├── bundle.sh                 ← Build + create .app bundle
│   ├── prepare_icon.py           ← Apply rounded corners + scale icon
│   └── generate_icon.py          ← Generate icon programmatically
└── Sources/
    ├── App/
    │   ├── main.swift
    │   └── AppDelegate.swift
    ├── Managers/
    │   ├── SMCKit.swift           ← IOKit SMC interface (temp, fan, fan min/max)
    │   ├── SystemMonitor.swift    ← CPU/RAM via host_statistics
    │   └── CaffeineManager.swift  ← IOPMAssertion (sleep + display sleep)
    ├── Models/
    │   ├── MonitorState.swift     ← Observable state + alert logic
    │   ├── SettingsManager.swift  ← JSON config (~/.config/rancage/)
    │   └── HistoryStore.swift     ← Graph data + cache (~/.cache/rancage/)
    ├── Utilities/
    │   ├── MenuBarIcons.swift     ← Programmatic template icons
    │   ├── MenuBarRenderer.swift  ← Render status bar as template image
    │   └── MenuBuilder.swift      ← Build dropdown menu
    └── Views/
        ├── MainWindowView.swift   ← Window with fixed sidebar
        ├── DashboardView.swift    ← Graphs + live stats + caffeine toggle
        ├── SettingsView.swift     ← All preferences + alerts config
        └── MiniGraphView.swift    ← Line chart component
```

## SMC Keys (Intel Mac)

| Key | Description |
|-----|-------------|
| TC0P | CPU Proximity Temperature |
| TG0P | GPU Proximity Temperature |
| F0Ac | Fan 0 Actual Speed (RPM) |
| F0Mn | Fan 0 Minimum Speed |
| F0Mx | Fan 0 Maximum Speed |
| FNum | Number of Fans |

## Icon

Untuk regenerate icon dari source:

```bash
# Save source icon ke assets/icon_raw.png, lalu:
python3 scripts/prepare_icon.py assets/icon_raw.png
```

## License

MIT — see [LICENSE](LICENSE)
