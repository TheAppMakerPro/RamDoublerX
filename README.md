# 🧠 RamDoubler X

### Modern Memory Optimizer for Apple Silicon Macs
*Inspired by Connectix RamDoubler (1994) — Reimagined for M4*

---

## Overview

| Field | Value |
|-------|-------|
| **Target** | Mac Mini M4 (24GB → 48GB effective) |
| **Platform** | macOS 14+ (Sonoma), Apple Silicon (arm64) |
| **Type** | Menu Bar Utility |
| **Language** | Swift 5.9 / SwiftUI |
| **Approach** | VM compression monitoring + aggressive memory reclamation |

## What It Does

RamDoubler X monitors macOS's built-in memory compression engine and gives you:

1. **Effective RAM Display** — Shows your true memory capacity including compression gains (e.g., "38.4 GB Effective" from 24GB physical)
2. **One-Click Optimization** — Purges disk caches, signals apps to release memory, reclaims inactive pages
3. **Auto-Optimize** — Triggers memory reclamation when usage exceeds your configured threshold
4. **Compressed RAM Disk** — Creates a fast APFS volume in RAM for scratch/temp files (no SSD wear)
5. **Real-Time Monitoring** — Memory pressure, compression ratios, swap usage, and breakdown charts

## How It Works (Technical)

Modern macOS already compresses memory at the kernel level (since Mavericks 10.9). The VM compressor typically achieves **1.5x–3.0x compression** on real workloads. RamDoubler X reads these statistics and provides tools to maximize the benefit:

### Memory Compression Pipeline
```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐    ┌─────────┐
│  Active RAM  │───▶│  Compressor  │───▶│  Compressed  │───▶│  Swap   │
│  (hot data)  │    │  (kernel VM) │    │  (in RAM)    │    │  (SSD)  │
└─────────────┘    └──────────────┘    └──────────────┘    └─────────┘
       24 GB            ~2x ratio          Fits more!        Last resort
```

### What RamDoubler X Adds
- **Visibility**: Displays effective memory, compression ratio, savings
- **Purge**: Clears disk caches (file system buffer cache) freeing physical pages
- **Memory Warning**: Sends notifications to apps so they release cached data
- **RAM Disk**: Keeps temp files in compressed RAM instead of hitting SSD swap
- **Auto-Trigger**: Proactively optimizes before the system starts heavy swapping

## Architecture

```
RamDoubler/
├── RamDoubler.xcodeproj
├── setup.sh                          # Project generation script
├── README.md
└── RamDoubler/
    ├── RamDoublerApp.swift           # Entry point + AppDelegate + Menu Bar
    ├── Info.plist                     # App config (LSUIElement = true)
    ├── RamDoubler.entitlements        # No sandbox (needs Mach APIs)
    ├── Models/
    │   └── AppSettings.swift          # UserDefaults-backed preferences
    ├── Services/
    │   ├── MemoryMonitor.swift        # Core: Mach VM stats + optimization
    │   └── RamDiskManager.swift       # Compressed RAM disk lifecycle
    ├── Views/
    │   ├── MainPopoverView.swift      # Dashboard popover UI
    │   └── SettingsView.swift         # Preferences window
    ├── Resources/
    └── Assets.xcassets/
```

### Data Flow
```
Mach Kernel (host_statistics64)
    │
    ▼
MemoryMonitor (2s polling)
    │
    ├──▶ MemoryStats struct (published)
    │       ├── Physical/Used/Free/Wired/Compressed pages
    │       ├── Compression ratio calculation
    │       ├── Effective memory = physical + savings
    │       └── Pressure level (nominal/warning/critical)
    │
    ├──▶ MainPopoverView (SwiftUI)
    │       ├── Circular gauge (effective vs target)
    │       ├── Memory breakdown bar
    │       └── Compression engine stats
    │
    ├──▶ AppDelegate (status bar)
    │       └── Updates title every 2s
    │
    └──▶ Auto-Optimizer (threshold check)
            └── Triggers purge + memory warning
```

## Build Instructions

### Option A: Quick Setup with xcodegen

```bash
# Install xcodegen
brew install xcodegen

# Clone/download the project, then:
cd RamDoubler
chmod +x setup.sh
./setup.sh

# Open in Xcode
open RamDoubler.xcodeproj
```

### Option B: Manual Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **macOS → App**
3. Settings:
   - Product Name: `RamDoubler`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Bundle ID: `com.ramdoubler.app`
4. Delete the default `ContentView.swift`
5. Copy all `.swift` files from the source tree into the project
6. Copy `Info.plist` and `RamDoubler.entitlements`
7. In project settings:
   - **General → Deployment Target**: macOS 14.0
   - **Signing → Disable Sandbox** (uncheck App Sandbox)
   - **Build Settings → Code Signing Identity**: "Sign to Run Locally"
   - Set **Info.plist File** → `RamDoubler/Info.plist`
   - Set **Code Sign Entitlements** → `RamDoubler/RamDoubler.entitlements`

### Build & Run

```bash
# Command line build
xcodebuild -project RamDoubler.xcodeproj \
  -scheme RamDoubler \
  -configuration Release \
  -arch arm64 \
  build

# Or just press ⌘R in Xcode
```

### Important: Permissions

The app needs elevated privileges for two features:
- **`purge` command**: Requires admin password (prompted via dialog)
- **RAM disk creation**: Uses `hdiutil` which may need permission

For the smoothest experience, you can grant the built app in:
**System Settings → Privacy & Security → Full Disk Access**

## Configuration

### Status Bar Display Modes
| Mode | Shows |
|------|-------|
| Effective RAM | `🟢 38.4GB` |
| Compression Ratio | `🟢 1.8x` |
| Memory Used | `🟢 16.2/24GB` |
| Icon Only | `🟢` |

### Auto-Optimize Settings
- **Threshold**: 60%–95% (default: 85%)
- **Actions**: Purge caches → signal apps → wait → report savings

### RAM Disk Sizes
| Size | Good For |
|------|----------|
| 512 MB | Browser cache redirect |
| 1 GB | Xcode derived data |
| 2 GB | General scratch (default) |
| 4 GB | Video editing temp files |
| 8 GB | Heavy Docker builds |

## Realistic Expectations

Let's be transparent about what this can and can't do:

### ✅ What It Actually Achieves
- **Shows you effective memory** that macOS is silently providing via compression
- **Reclaims 0.5–4 GB** per optimization by purging caches and inactive pages
- **Reduces SSD swap pressure** by keeping the compressor working efficiently
- **RAM disk eliminates SSD writes** for temporary data
- **Typical effective RAM**: 30–42 GB from 24 GB physical (1.3x–1.8x)

### ⚠️ What It Cannot Do
- **Truly double your RAM** — the "48GB target" is aspirational; real gains are 1.3x–1.8x
- **Add physical memory** — no software can change hardware
- **Break macOS limits** — works within Apple's VM subsystem, not around it
- **Help with wired memory** — kernel-locked memory can't be compressed or freed

### 💡 When It Helps Most
- Running many apps simultaneously (Chrome + Xcode + Docker + Figma)
- Preventing swap thrashing during memory-intensive tasks
- Keeping the system responsive under heavy memory load
- Reducing SSD wear from swap writes

## Expansion Hooks

### Planned Features (v1.x)
- [ ] Per-app memory tracking and kill recommendations
- [ ] Memory usage timeline graph (last 24h)
- [ ] Shortcuts/Automator integration for scripted optimization
- [ ] Configurable RAM disk mount paths (symlink browser cache, etc.)
- [ ] Menu bar sparkline chart

### Advanced Features (v2.0)
- [ ] Memory advisor AI (suggests which apps to close)
- [ ] Scheduled optimization (e.g., every 30 minutes)
- [ ] Export memory reports (CSV/JSON)
- [ ] Widget for macOS desktop
- [ ] Privileged helper tool (avoid repeated admin prompts)

## License

MIT — Use freely. Inspired by the legendary Connectix RamDoubler.
