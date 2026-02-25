// ============================================================================
// AppSettings.swift — Persistent Settings
// ============================================================================

import Foundation
import Combine

enum StatusBarDisplayMode: String, CaseIterable, Identifiable {
    case effectiveRam    = "Effective RAM"
    case compressionRatio = "Compression Ratio"
    case memoryUsed      = "Memory Used"
    case iconOnly        = "Icon Only"
    
    var id: String { rawValue }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // ── Status Bar ─────────────────────────────────────────────────
    @Published var statusBarDisplayMode: StatusBarDisplayMode {
        didSet { UserDefaults.standard.set(statusBarDisplayMode.rawValue, forKey: "statusBarDisplayMode") }
    }
    
    // ── Auto-Optimize ──────────────────────────────────────────────
    @Published var autoOptimizeEnabled: Bool {
        didSet { UserDefaults.standard.set(autoOptimizeEnabled, forKey: "autoOptimizeEnabled") }
    }
    
    /// Memory usage % threshold to trigger auto-optimization (0-100)
    @Published var autoOptimizeThreshold: Double {
        didSet { UserDefaults.standard.set(autoOptimizeThreshold, forKey: "autoOptimizeThreshold") }
    }
    
    // ── RAM Disk ───────────────────────────────────────────────────
    @Published var ramDiskAutoMount: Bool {
        didSet { UserDefaults.standard.set(ramDiskAutoMount, forKey: "ramDiskAutoMount") }
    }
    
    @Published var ramDiskSizeMB: Int {
        didSet { UserDefaults.standard.set(ramDiskSizeMB, forKey: "ramDiskSizeMB") }
    }
    
    // ── Launch at Login ────────────────────────────────────────────
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    
    // ── Target Memory Display ──────────────────────────────────────
    @Published var targetMemoryGB: Double {
        didSet { UserDefaults.standard.set(targetMemoryGB, forKey: "targetMemoryGB") }
    }
    
    // ── Notifications ──────────────────────────────────────────────
    @Published var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: "showNotifications") }
    }
    
    private init() {
        let defaults = UserDefaults.standard
        
        let modeRaw = defaults.string(forKey: "statusBarDisplayMode") ?? StatusBarDisplayMode.effectiveRam.rawValue
        self.statusBarDisplayMode = StatusBarDisplayMode(rawValue: modeRaw) ?? .effectiveRam
        
        self.autoOptimizeEnabled = defaults.bool(forKey: "autoOptimizeEnabled")
        
        let threshold = defaults.double(forKey: "autoOptimizeThreshold")
        self.autoOptimizeThreshold = threshold > 0 ? threshold : 85.0
        
        self.ramDiskAutoMount = defaults.bool(forKey: "ramDiskAutoMount")
        
        let diskSize = defaults.integer(forKey: "ramDiskSizeMB")
        self.ramDiskSizeMB = diskSize > 0 ? diskSize : 2048
        
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        
        let targetMem = defaults.double(forKey: "targetMemoryGB")
        self.targetMemoryGB = targetMem > 0 ? targetMem : 48.0
        
        let notifSet = defaults.object(forKey: "showNotifications")
        self.showNotifications = notifSet != nil ? defaults.bool(forKey: "showNotifications") : true
    }
}
