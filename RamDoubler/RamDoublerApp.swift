// ============================================================================
// RamDoubler X — Modern Memory Optimizer for Apple Silicon Macs
// ============================================================================
// Inspired by the legendary Connectix RamDoubler (1994)
// Reimagined for macOS on Apple Silicon (M4 Mac Mini)
//
// WHAT IT DOES:
// • Monitors real-time memory compression ratios from the macOS VM subsystem
// • Displays "effective" memory = physical + compression savings
// • Aggressively purges inactive/purgeable memory on demand or automatically
// • Creates optional compressed RAM disk for fast temp storage
// • Shows memory pressure status and auto-optimizes at configurable thresholds
//
// ARCHITECTURE: SwiftUI Menu Bar App + privileged helper for purge commands
// TARGET: macOS 14+ (Sonoma), Apple Silicon (arm64)
// ============================================================================

import SwiftUI

@main
struct RamDoublerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar only — no main window
        Settings {
            SettingsView()
                .environmentObject(MemoryMonitor.shared)
                .environmentObject(AppSettings.shared)
        }
    }
}

// ============================================================================
// MARK: - App Delegate (Menu Bar Setup)
// ============================================================================
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let memoryMonitor = MemoryMonitor.shared
    private var updateTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // ── Create Status Bar Item ──────────────────────────────────
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateStatusBarTitle(button: button)
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // ── Create Popover ─────────────────────────────────────────
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MainPopoverView()
                .environmentObject(memoryMonitor)
                .environmentObject(AppSettings.shared)
        )
        
        // ── Start Memory Monitoring ────────────────────────────────
        memoryMonitor.startMonitoring()
        
        // ── Update Status Bar Every 2 Seconds ─────────────────────
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }
            self.updateStatusBarTitle(button: button)
        }
        
        // Hide dock icon — menu bar app only
        NSApp.setActivationPolicy(.accessory)
    }
    
    // ── Status Bar Display ─────────────────────────────────────────
    private func updateStatusBarTitle(button: NSStatusBarButton) {
        let stats = memoryMonitor.currentStats
        let effectiveGB = stats.effectiveMemoryGB
        let pressure = stats.pressureLevel
        
        let icon: String
        switch pressure {
        case .nominal:  icon = "🟢"
        case .warning:  icon = "🟡"
        case .critical: icon = "🔴"
        }
        
        let displayMode = AppSettings.shared.statusBarDisplayMode
        switch displayMode {
        case .effectiveRam:
            button.title = "\(icon) \(String(format: "%.1f", effectiveGB))GB"
        case .compressionRatio:
            button.title = "\(icon) \(String(format: "%.1fx", stats.compressionRatio))"
        case .memoryUsed:
            let usedGB = stats.usedMemoryGB
            let physicalGB = stats.physicalMemoryGB
            button.title = "\(icon) \(String(format: "%.1f", usedGB))/\(String(format: "%.0f", physicalGB))GB"
        case .iconOnly:
            button.title = icon
        }
    }
    
    // ── Toggle Popover ─────────────────────────────────────────────
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure popover gets focus
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        memoryMonitor.stopMonitoring()
        RamDiskManager.shared.unmountRamDisk()
    }
}
