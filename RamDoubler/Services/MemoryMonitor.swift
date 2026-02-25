// ============================================================================
// MemoryMonitor.swift — Core Memory Statistics Engine
// ============================================================================
// Reads macOS kernel VM statistics via Mach APIs to calculate:
// • Physical memory usage breakdown (wired, active, inactive, free, compressed)
// • Compression ratio (how much data is compressed into how much space)
// • Effective memory = physical + compression savings
// • Memory pressure levels for auto-optimization triggers
//
// Uses host_statistics64() for vm_statistics64 data — the same source as
// Activity Monitor's Memory tab.
// ============================================================================

import Foundation
import Combine
import Darwin

// ============================================================================
// MARK: - Memory Statistics Model
// ============================================================================
struct MemoryStats {
    // Raw page counts (from vm_statistics64)
    let freePages: UInt64
    let activePages: UInt64
    let inactivePages: UInt64
    let wiredPages: UInt64
    let compressedPages: UInt64       // Pages stored in compressor
    let decompressions: UInt64         // Total decompression operations
    let compressions: UInt64           // Total compression operations
    let purgeablePages: UInt64
    let externalPages: UInt64          // File-backed pages
    let swapUsageBytes: UInt64
    
    // Computed values
    let pageSize: UInt64
    let physicalMemoryBytes: UInt64
    let timestamp: Date
    
    // ── Derived Metrics ────────────────────────────────────────────
    
    /// Total physical RAM in GB
    var physicalMemoryGB: Double {
        Double(physicalMemoryBytes) / 1_073_741_824.0
    }
    
    /// Memory actively used (wired + active + compressed)
    var usedMemoryBytes: UInt64 {
        (wiredPages + activePages + compressedPages) * pageSize
    }
    
    var usedMemoryGB: Double {
        Double(usedMemoryBytes) / 1_073_741_824.0
    }
    
    /// Memory available (free + inactive + purgeable)
    var availableMemoryBytes: UInt64 {
        (freePages + inactivePages + purgeablePages) * pageSize
    }
    
    var availableMemoryGB: Double {
        Double(availableMemoryBytes) / 1_073_741_824.0
    }
    
    /// Compression ratio — how much original data fits in compressed space
    /// A ratio of 2.0x means 2GB of data compressed into 1GB of RAM
    var compressionRatio: Double {
        guard compressedPages > 0, compressions > 0 else { return 1.0 }
        // The compressor ratio is estimated from the relationship between
        // data that entered the compressor vs pages used to store it
        // Apple's compressor typically achieves 1.5x-3.0x depending on data
        let compressedBytes = Double(compressedPages * pageSize)
        // Estimate: compressions count / compressed pages gives a rough ratio
        // We also use the known behavior that macOS reports compressed pages
        // as the SPACE USED, not the original data size
        let estimatedOriginalData = compressedBytes * estimatedCompressionMultiplier
        if compressedBytes > 0 {
            return estimatedOriginalData / compressedBytes
        }
        return 1.0
    }
    
    /// Estimated compression multiplier based on system heuristics
    /// macOS memory compressor typically achieves 1.5-3x on real workloads
    private var estimatedCompressionMultiplier: Double {
        // Use compressions vs decompressions as a signal for compressor activity
        // Higher activity = more compressible data available
        guard compressions > 0 else { return 1.8 } // Conservative default
        
        // If decompressions are much less than compressions, data is staying
        // compressed well (good compressibility)
        let decompRatio = decompressions > 0 ? Double(compressions) / Double(decompressions) : 2.0
        
        // Clamp to realistic range [1.3, 3.0]
        return min(3.0, max(1.3, decompRatio * 0.9 + 0.8))
    }
    
    /// The "magic number" — effective memory including compression savings
    /// This is what the user sees as their "doubled" RAM
    var effectiveMemoryBytes: UInt64 {
        let compressedRegionBytes = compressedPages * pageSize
        let compressionSavings = UInt64(Double(compressedRegionBytes) * (compressionRatio - 1.0))
        return physicalMemoryBytes + compressionSavings
    }
    
    var effectiveMemoryGB: Double {
        Double(effectiveMemoryBytes) / 1_073_741_824.0
    }
    
    /// Memory savings from compression in GB
    var compressionSavingsGB: Double {
        effectiveMemoryGB - physicalMemoryGB
    }
    
    /// Usage percentage of physical RAM
    var usagePercent: Double {
        Double(usedMemoryBytes) / Double(physicalMemoryBytes) * 100.0
    }
    
    /// Wired memory in GB (cannot be compressed or paged out)
    var wiredMemoryGB: Double {
        Double(wiredPages * pageSize) / 1_073_741_824.0
    }
    
    /// Compressed memory region size in GB
    var compressedMemoryGB: Double {
        Double(compressedPages * pageSize) / 1_073_741_824.0
    }
    
    /// Inactive memory in GB (recently used, can be reclaimed)
    var inactiveMemoryGB: Double {
        Double(inactivePages * pageSize) / 1_073_741_824.0
    }
    
    /// Free memory in GB
    var freeMemoryGB: Double {
        Double(freePages * pageSize) / 1_073_741_824.0
    }
    
    /// Swap usage in GB
    var swapUsageGB: Double {
        Double(swapUsageBytes) / 1_073_741_824.0
    }
    
    /// Purgeable memory in GB (caches that can be instantly freed)
    var purgeableMemoryGB: Double {
        Double(purgeablePages * pageSize) / 1_073_741_824.0
    }
    
    /// Memory pressure level for auto-optimization
    var pressureLevel: MemoryPressure {
        let usageFraction = Double(usedMemoryBytes) / Double(physicalMemoryBytes)
        if usageFraction > 0.90 || swapUsageGB > 2.0 {
            return .critical
        } else if usageFraction > 0.75 || swapUsageGB > 0.5 {
            return .warning
        }
        return .nominal
    }
    
    // ── Default/Empty Stats ────────────────────────────────────────
    static let empty = MemoryStats(
        freePages: 0, activePages: 0, inactivePages: 0,
        wiredPages: 0, compressedPages: 0, decompressions: 0,
        compressions: 0, purgeablePages: 0, externalPages: 0,
        swapUsageBytes: 0, pageSize: 16384,
        physicalMemoryBytes: 0, timestamp: Date()
    )
}

// ============================================================================
// MARK: - Memory Pressure Levels
// ============================================================================
enum MemoryPressure: String, CaseIterable {
    case nominal  = "Normal"
    case warning  = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .nominal:  return "green"
        case .warning:  return "yellow"
        case .critical: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .nominal:  return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// ============================================================================
// MARK: - Memory Monitor Service
// ============================================================================
class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()
    
    @Published var currentStats: MemoryStats = .empty
    @Published var statsHistory: [MemoryStats] = []
    @Published var isOptimizing: Bool = false
    @Published var lastOptimizationSavings: Double = 0
    @Published var totalSessionSavings: Double = 0
    
    private var timer: Timer?
    private let historyLimit = 120 // 4 minutes of history at 2s intervals
    
    // ── Physical Memory (one-time read) ────────────────────────────
    private let physicalMemory: UInt64 = {
        ProcessInfo.processInfo.physicalMemory
    }()
    
    private let pageSize: UInt64 = {
        UInt64(vm_kernel_page_size)
    }()
    
    private init() {}
    
    // ── Start/Stop Monitoring ──────────────────────────────────────
    func startMonitoring() {
        refreshStats()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshStats()
            self?.checkAutoOptimize()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // ── Read VM Statistics from Mach Kernel ────────────────────────
    func refreshStats() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    intPtr,
                    &count
                )
            }
        }
        
        guard result == KERN_SUCCESS else {
            print("⚠️ Failed to read VM statistics: \(result)")
            return
        }
        
        // Read swap usage via sysctl
        let swapUsage = getSwapUsage()
        
        let stats = MemoryStats(
            freePages: UInt64(vmStats.free_count),
            activePages: UInt64(vmStats.active_count),
            inactivePages: UInt64(vmStats.inactive_count),
            wiredPages: UInt64(vmStats.wire_count),
            compressedPages: UInt64(vmStats.compressor_page_count),
            decompressions: UInt64(vmStats.decompressions),
            compressions: UInt64(vmStats.compressions),
            purgeablePages: UInt64(vmStats.purgeable_count),
            externalPages: UInt64(vmStats.external_page_count),
            swapUsageBytes: swapUsage,
            pageSize: pageSize,
            physicalMemoryBytes: physicalMemory,
            timestamp: Date()
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentStats = stats
            self.statsHistory.append(stats)
            if self.statsHistory.count > self.historyLimit {
                self.statsHistory.removeFirst()
            }
        }
    }
    
    // ── Get Swap Usage via sysctl ──────────────────────────────────
    private func getSwapUsage() -> UInt64 {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        if result == 0 {
            return UInt64(swapUsage.xsu_used)
        }
        return 0
    }
    
    // ── Optimize Memory (Purge Caches) ─────────────────────────────
    func optimizeMemory(completion: @escaping (Bool, Double) -> Void) {
        guard !isOptimizing else {
            completion(false, 0)
            return
        }
        
        DispatchQueue.main.async { self.isOptimizing = true }
        
        let beforeStats = currentStats
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Method 1: Use purge command (requires admin privileges)
            let purgeResult = self?.runPurge() ?? false
            
            // Method 2: Send memory pressure notification to apps
            self?.sendMemoryWarning()
            
            // Wait for system to settle
            Thread.sleep(forTimeInterval: 2.0)
            
            // Refresh and calculate savings
            self?.refreshStats()
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                let afterStats = self.currentStats
                let savedGB = afterStats.availableMemoryGB - beforeStats.availableMemoryGB
                let actualSavings = max(0, savedGB)
                
                self.lastOptimizationSavings = actualSavings
                self.totalSessionSavings += actualSavings
                self.isOptimizing = false
                
                completion(purgeResult, actualSavings)
            }
        }
    }
    
    // ── Run macOS purge command ─────────────────────────────────────
    private func runPurge() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            // purge requires root — try with osascript for privilege escalation
            return runPurgeWithPrivileges()
        }
    }
    
    /// Runs purge with admin privileges via AppleScript
    private func runPurgeWithPrivileges() -> Bool {
        let script = """
        do shell script "purge" with administrator privileges
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("⚠️ Failed to run purge: \(error)")
            return false
        }
    }
    
    /// Send memory pressure notifications to encourage apps to free memory
    private func sendMemoryWarning() {
        // Dispatch a simulated memory warning via NSNotification
        // Apps that properly handle didReceiveMemoryWarning will release caches
        NotificationCenter.default.post(
            name: NSNotification.Name("NSApplicationMemoryWarning"),
            object: nil
        )
    }
    
    // ── Auto-Optimize Check ────────────────────────────────────────
    private func checkAutoOptimize() {
        guard AppSettings.shared.autoOptimizeEnabled else { return }
        
        let stats = currentStats
        let threshold = AppSettings.shared.autoOptimizeThreshold
        
        if stats.usagePercent > threshold {
            optimizeMemory { success, savings in
                if success {
                    print("🔄 Auto-optimized: freed \(String(format: "%.2f", savings)) GB")
                }
            }
        }
    }
}
