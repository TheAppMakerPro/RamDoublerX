// ============================================================================
// MainPopoverView.swift — Primary UI (Menu Bar Popover)
// ============================================================================
// Displays the RamDoubler dashboard with:
// • Circular gauge showing effective vs physical RAM
// • Memory breakdown bars
// • Quick-optimize button
// • RAM disk controls
// • Compression statistics
// ============================================================================

import SwiftUI

struct MainPopoverView: View {
    @EnvironmentObject var monitor: MemoryMonitor
    @EnvironmentObject var settings: AppSettings
    @StateObject private var ramDisk = RamDiskManager.shared
    @State private var optimizeMessage: String?
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────────
            headerSection
            
            Divider().padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 16) {
                    // ── Effective Memory Gauge ──────────────────────
                    effectiveMemoryGauge
                    
                    // ── Memory Breakdown ────────────────────────────
                    memoryBreakdown
                    
                    // ── Compression Stats ───────────────────────────
                    compressionStats
                    
                    // ── Optimize Button ─────────────────────────────
                    optimizeSection
                    
                    // ── RAM Disk Section ────────────────────────────
                    ramDiskSection
                }
                .padding()
            }
            
            Divider()
            
            // ── Footer ─────────────────────────────────────────────
            footerSection
        }
        .frame(width: 380, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // ====================================================================
    // MARK: - Header
    // ====================================================================
    private var headerSection: some View {
        HStack {
            Image(systemName: "memorychip.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("RamDoubler X")
                    .font(.headline)
                Text("Memory Optimizer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Pressure indicator
            HStack(spacing: 4) {
                Image(systemName: monitor.currentStats.pressureLevel.icon)
                    .foregroundColor(pressureColor)
                Text(monitor.currentStats.pressureLevel.rawValue)
                    .font(.caption)
                    .foregroundColor(pressureColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pressureColor.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
    
    private var pressureColor: Color {
        switch monitor.currentStats.pressureLevel {
        case .nominal:  return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }
    
    // ====================================================================
    // MARK: - Effective Memory Gauge
    // ====================================================================
    private var effectiveMemoryGauge: some View {
        let stats = monitor.currentStats
        let physical = stats.physicalMemoryGB
        let effective = stats.effectiveMemoryGB
        let target = settings.targetMemoryGB
        let progress = min(effective / target, 1.0)
        
        return VStack(spacing: 8) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .rotationEffect(.degrees(135))
                
                // Physical RAM arc
                Circle()
                    .trim(from: 0.0, to: 0.75 * (physical / target))
                    .stroke(Color.blue.opacity(0.3), lineWidth: 12)
                    .rotationEffect(.degrees(135))
                
                // Effective RAM arc (compression gains)
                Circle()
                    .trim(from: 0.0, to: 0.75 * progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 0.5), value: effective)
                
                // Center text
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", effective))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("GB Effective")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("+\(String(format: "%.1f", stats.compressionSavingsGB)) GB")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .frame(width: 160, height: 160)
            
            // Labels below gauge
            HStack {
                VStack {
                    Text(String(format: "%.0f GB", physical))
                        .font(.caption.bold())
                    Text("Physical")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(String(format: "%.1fx", stats.compressionRatio))
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                    Text("Compression")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(String(format: "%.0f GB", target))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("Target")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // ====================================================================
    // MARK: - Memory Breakdown
    // ====================================================================
    private var memoryBreakdown: some View {
        let stats = monitor.currentStats
        let total = stats.physicalMemoryGB
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Memory Breakdown")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            // Stacked bar
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 1) {
                    // Wired
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: max(2, width * stats.wiredMemoryGB / total))
                    // Active
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: max(2, width * Double(stats.activePages * stats.pageSize) / Double(stats.physicalMemoryBytes)))
                    // Compressed
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: max(2, width * stats.compressedMemoryGB / total))
                    // Inactive
                    Rectangle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: max(2, width * stats.inactiveMemoryGB / total))
                    // Free
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                }
                .frame(height: 16)
                .cornerRadius(4)
            }
            .frame(height: 16)
            
            // Legend
            HStack(spacing: 12) {
                legendItem("Wired", color: .red.opacity(0.7), value: stats.wiredMemoryGB)
                legendItem("Active", color: .orange, value: Double(stats.activePages * stats.pageSize) / 1_073_741_824.0)
                legendItem("Compressed", color: .cyan, value: stats.compressedMemoryGB)
                legendItem("Free", color: .green.opacity(0.5), value: stats.freeMemoryGB)
            }
            .font(.system(size: 10))
            
            // Swap indicator
            if stats.swapUsageGB > 0.01 {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption2)
                    Text("Swap: \(String(format: "%.2f", stats.swapUsageGB)) GB")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    private func legendItem(_ label: String, color: Color, value: Double) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(String(format: "%.1f", value))G")
                .foregroundColor(.secondary)
        }
    }
    
    // ====================================================================
    // MARK: - Compression Stats
    // ====================================================================
    private var compressionStats: some View {
        let stats = monitor.currentStats
        
        return VStack(alignment: .leading, spacing: 6) {
            Text("Compression Engine")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack {
                statBox(
                    title: "Compressions",
                    value: formatLargeNumber(stats.compressions),
                    icon: "arrow.down.right.circle"
                )
                statBox(
                    title: "Decompressions",
                    value: formatLargeNumber(stats.decompressions),
                    icon: "arrow.up.left.circle"
                )
                statBox(
                    title: "Purgeable",
                    value: String(format: "%.1fG", stats.purgeableMemoryGB),
                    icon: "trash.circle"
                )
            }
        }
    }
    
    private func statBox(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }
    
    private func formatLargeNumber(_ n: UInt64) -> String {
        if n > 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
        if n > 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n > 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
    
    // ====================================================================
    // MARK: - Optimize Section
    // ====================================================================
    private var optimizeSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                monitor.optimizeMemory { success, savings in
                    if success {
                        optimizeMessage = "Freed \(String(format: "%.2f", savings)) GB"
                    } else {
                        optimizeMessage = "Optimization running..."
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        optimizeMessage = nil
                    }
                }
            }) {
                HStack {
                    if monitor.isOptimizing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bolt.circle.fill")
                    }
                    Text(monitor.isOptimizing ? "Optimizing..." : "Optimize Now")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(monitor.isOptimizing)
            
            if let msg = optimizeMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            if monitor.totalSessionSavings > 0 {
                Text("Session savings: \(String(format: "%.2f", monitor.totalSessionSavings)) GB freed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // ====================================================================
    // MARK: - RAM Disk Section
    // ====================================================================
    private var ramDiskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fast RAM Disk")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            if ramDisk.isRamDiskMounted {
                HStack {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text(ramDisk.ramDiskPath)
                            .font(.caption)
                        Text("\(String(format: "%.0f", ramDisk.ramDiskUsedMB)) / \(ramDisk.ramDiskSizeMB) MB used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Eject") {
                        ramDisk.unmountRamDisk()
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            } else {
                Button(action: {
                    DispatchQueue.global().async {
                        _ = ramDisk.createRamDisk(sizeMB: settings.ramDiskSizeMB)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create \(settings.ramDiskSizeMB)MB RAM Disk")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
            }
        }
    }
    
    // ====================================================================
    // MARK: - Footer
    // ====================================================================
    private var footerSection: some View {
        HStack {
            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("System Settings")
            
            Button(action: {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("RamDoubler Settings")
            
            Spacer()
            
            Button("Quit") {
                RamDiskManager.shared.unmountRamDisk()
                NSApp.terminate(nil)
            }
            .controlSize(.small)
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
