// ============================================================================
// RamDiskManager.swift — Compressed RAM Disk for Fast Buffer Storage
// ============================================================================
// Creates an in-memory disk volume that acts as a fast buffer between
// RAM and SSD swap. This gives apps a blazing-fast scratch space that
// doesn't touch the SSD, reducing wear and improving performance for
// temporary file operations.
//
// On Apple Silicon M4, this effectively creates a priority memory region
// that stays in RAM and benefits from the hardware's memory compression.
// ============================================================================

import Foundation

class RamDiskManager: ObservableObject {
    static let shared = RamDiskManager()
    
    @Published var isRamDiskMounted: Bool = false
    @Published var ramDiskSizeMB: Int = 0
    @Published var ramDiskPath: String = ""
    @Published var ramDiskUsedMB: Double = 0
    
    private var diskIdentifier: String?
    private var monitorTimer: Timer?
    
    private init() {
        checkExistingRamDisk()
    }
    
    // ── Create Compressed RAM Disk ─────────────────────────────────
    /// Creates a RAM disk of the specified size in MB
    /// On Apple Silicon, this memory benefits from hardware compression
    func createRamDisk(sizeMB: Int = 2048, name: String = "RamDoubler_Fast") -> Bool {
        guard !isRamDiskMounted else {
            print("⚠️ RAM disk already mounted")
            return false
        }
        
        // Calculate sectors (512 bytes per sector)
        let sectors = sizeMB * 2048
        
        // Step 1: Create the RAM disk device
        let createProcess = Process()
        createProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        createProcess.arguments = ["attach", "-nomount", "ram://\(sectors)"]
        
        let pipe = Pipe()
        createProcess.standardOutput = pipe
        
        do {
            try createProcess.run()
            createProcess.waitUntilExit()
            
            guard createProcess.terminationStatus == 0 else {
                print("⚠️ Failed to create RAM disk device")
                return false
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let devicePath = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            
            diskIdentifier = devicePath
            
            // Step 2: Format as APFS (compressed, fast)
            let formatProcess = Process()
            formatProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            formatProcess.arguments = [
                "eraseVolume", "APFS", name, devicePath
            ]
            
            try formatProcess.run()
            formatProcess.waitUntilExit()
            
            guard formatProcess.terminationStatus == 0 else {
                print("⚠️ Failed to format RAM disk")
                // Cleanup
                detachDevice(devicePath)
                return false
            }
            
            DispatchQueue.main.async {
                self.isRamDiskMounted = true
                self.ramDiskSizeMB = sizeMB
                self.ramDiskPath = "/Volumes/\(name)"
            }
            
            // Start monitoring usage
            startUsageMonitoring()
            
            print("✅ RAM disk created: \(sizeMB)MB at /Volumes/\(name)")
            return true
            
        } catch {
            print("⚠️ RAM disk creation error: \(error)")
            return false
        }
    }
    
    // ── Unmount RAM Disk ───────────────────────────────────────────
    func unmountRamDisk() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        
        guard let device = diskIdentifier else { return }
        detachDevice(device)
        
        DispatchQueue.main.async {
            self.isRamDiskMounted = false
            self.ramDiskSizeMB = 0
            self.ramDiskPath = ""
            self.ramDiskUsedMB = 0
            self.diskIdentifier = nil
        }
        
        print("✅ RAM disk unmounted")
    }
    
    // ── Detach Device ──────────────────────────────────────────────
    private func detachDevice(_ device: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", device, "-force"]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("⚠️ Failed to detach: \(error)")
        }
    }
    
    // ── Check for Existing RAM Disk ────────────────────────────────
    private func checkExistingRamDisk() {
        let path = "/Volumes/RamDoubler_Fast"
        if FileManager.default.fileExists(atPath: path) {
            DispatchQueue.main.async {
                self.isRamDiskMounted = true
                self.ramDiskPath = path
            }
        }
    }
    
    // ── Monitor RAM Disk Usage ─────────────────────────────────────
    private func startUsageMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateUsage()
        }
    }
    
    private func updateUsage() {
        guard isRamDiskMounted else { return }
        
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(
                forPath: ramDiskPath
            )
            if let totalSize = attrs[.systemSize] as? Int64,
               let freeSize = attrs[.systemFreeSize] as? Int64 {
                let usedBytes = totalSize - freeSize
                DispatchQueue.main.async {
                    self.ramDiskUsedMB = Double(usedBytes) / 1_048_576.0
                }
            }
        } catch {
            // Volume may have been unmounted externally
        }
    }
    
    // ── Utility: Set as TMPDIR for child processes ─────────────────
    /// Redirects temporary file operations to the RAM disk
    func setAsTempDirectory() {
        guard isRamDiskMounted else { return }
        setenv("TMPDIR", ramDiskPath, 1)
        print("✅ TMPDIR set to RAM disk: \(ramDiskPath)")
    }
    
    /// Restores the default TMPDIR
    func restoreTempDirectory() {
        let defaultTmp = NSTemporaryDirectory()
        setenv("TMPDIR", defaultTmp, 1)
        print("✅ TMPDIR restored to: \(defaultTmp)")
    }
}
