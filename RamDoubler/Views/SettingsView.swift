// ============================================================================
// SettingsView.swift — App Preferences Panel
// ============================================================================

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: MemoryMonitor
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            optimizationTab
                .tabItem {
                    Label("Optimization", systemImage: "bolt.circle")
                }
            
            ramDiskTab
                .tabItem {
                    Label("RAM Disk", systemImage: "internaldrive")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
    }
    
    // ── General Tab ────────────────────────────────────────────────
    private var generalTab: some View {
        Form {
            Section("Status Bar") {
                Picker("Display Mode", selection: $settings.statusBarDisplayMode) {
                    ForEach(StatusBarDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Target Memory") {
                HStack {
                    Text("Target Effective RAM:")
                    Spacer()
                    TextField("GB", value: $settings.targetMemoryGB, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("GB")
                }
                Text("Physical RAM: \(String(format: "%.0f", monitor.currentStats.physicalMemoryGB)) GB — Target should be 1.5x-2.5x physical")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Startup") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                
                Toggle("Show Notifications", isOn: $settings.showNotifications)
            }
        }
        .padding()
    }
    
    // ── Optimization Tab ───────────────────────────────────────────
    private var optimizationTab: some View {
        Form {
            Section("Auto-Optimization") {
                Toggle("Enable Auto-Optimize", isOn: $settings.autoOptimizeEnabled)
                
                if settings.autoOptimizeEnabled {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Trigger at:")
                            Spacer()
                            Text("\(String(format: "%.0f", settings.autoOptimizeThreshold))% memory usage")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.autoOptimizeThreshold, in: 60...95, step: 5)
                    }
                }
            }
            
            Section("Optimization Actions") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Purge disk caches (requires admin)", systemImage: "trash.circle")
                    Label("Signal apps to release memory", systemImage: "bell.badge")
                    Label("Compress inactive pages", systemImage: "archivebox")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Section("Session Statistics") {
                LabeledContent("Total Memory Freed") {
                    Text(String(format: "%.2f GB", monitor.totalSessionSavings))
                }
                LabeledContent("Last Optimization") {
                    Text(String(format: "%.2f GB freed", monitor.lastOptimizationSavings))
                }
            }
        }
        .padding()
    }
    
    // ── RAM Disk Tab ───────────────────────────────────────────────
    private var ramDiskTab: some View {
        Form {
            Section("Compressed RAM Disk") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Creates an in-memory APFS volume for blazing-fast temporary storage. Data is compressed by Apple Silicon hardware and stays in RAM — no SSD wear.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Size:")
                    Spacer()
                    Picker("", selection: $settings.ramDiskSizeMB) {
                        Text("512 MB").tag(512)
                        Text("1 GB").tag(1024)
                        Text("2 GB").tag(2048)
                        Text("4 GB").tag(4096)
                        Text("8 GB").tag(8192)
                    }
                    .frame(width: 120)
                }
                
                Toggle("Auto-mount at launch", isOn: $settings.ramDiskAutoMount)
            }
            
            Section("Use Cases") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Xcode derived data", systemImage: "hammer")
                    Label("Browser cache", systemImage: "globe")
                    Label("Video editing scratch", systemImage: "film")
                    Label("Docker build layers", systemImage: "shippingbox")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // ── About Tab ──────────────────────────────────────────────────
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "memorychip.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("RamDoubler X")
                .font(.title.bold())
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Inspired by Connectix RamDoubler (1994)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("How It Works")
                    .font(.headline)
                Text("""
                macOS already compresses memory in the kernel. RamDoubler X monitors \
                this compression, displays your effective memory capacity, and provides \
                tools to aggressively reclaim unused memory — giving you the practical \
                equivalent of more RAM.
                """)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    // ── Launch at Login Helper ─────────────────────────────────────
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("⚠️ Failed to set launch at login: \(error)")
        }
    }
}
