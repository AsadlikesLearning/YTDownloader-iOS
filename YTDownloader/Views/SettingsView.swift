import SwiftUI

struct SettingsView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var storageUsed: String = "Calculating..."
    @State private var showingClearAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Download & Photos Preferences
                Section(header: Text("Download Preferences")) {
                    Toggle("Auto-Save to Camera Roll", isOn: $downloadManager.isAutoSaveToPhotosEnabled)
                        .tint(.red)
                    
                    Text("When enabled, finished video downloads are automatically saved to your iPhone Photos app under 'YTDownloader'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Stream Extraction Engine
                Section(header: Text("Stream Resolver Engine")) {
                    Picker("Engine", selection: $downloadManager.selectedEngine) {
                        ForEach(ResolverEngine.allCases) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    
                    if downloadManager.selectedEngine == .cobalt || downloadManager.selectedEngine == .auto {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Resolver API Endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("https://api.cobalt.tools", text: $downloadManager.customCobaltEndpoint)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    Text("Direct YouTube uses native on-device Innertube queries. Cobalt Engine bypasses client cipher challenges and provides direct high-bitrate 1080p/4K streams.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Storage Management
                Section(header: Text("Storage")) {
                    HStack {
                        Text("Downloads Storage")
                        Spacer()
                        Text(storageUsed)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive, action: {
                        showingClearAlert = true
                    }) {
                        Text("Clear All Downloaded Media")
                    }
                }
                
                // MARK: - Sideloading Information
                Section(header: Text("Sideloading Details")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (Sideload Edition)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Sideload Target")
                        Spacer()
                        Text("iPhone (iOS 16+)")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink {
                        SideloadingGuideDetailView()
                    } label: {
                        Label("Sideloading Guide & Tips", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                calculateStorage()
            }
            .alert("Delete All Media?", isPresented: $showingClearAlert) {
                Button("Delete", role: .destructive) {
                    clearAllMedia()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all downloaded videos and audio from your device storage.")
            }
        }
    }
    
    private func calculateStorage() {
        Task.detached(priority: .background) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dir = docs.appendingPathComponent("YTDownloads", isDirectory: true)
            
            var totalSize: Int64 = 0
            if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            let formatted = formatter.string(fromByteCount: totalSize)
            
            await MainActor.run {
                self.storageUsed = formatted
            }
        }
    }
    
    private func clearAllMedia() {
        for item in downloadManager.downloads {
            downloadManager.deleteDownload(item: item)
        }
        calculateStorage()
    }
}

struct SideloadingGuideDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sideloading On Your iPhone")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Because downloading YouTube videos directly is not permitted in Apple's official App Store guidelines, this app is built as an open-source native iOS app for direct installation onto your personal device.")
                    .font(.body)
                
                Divider()
                
                Text("Supported Installation Methods:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("**AltStore / SideStore**: Free installation via your personal Apple ID. SideStore allows wireless refreshes without needing a computer running every week.", systemImage: "1.circle.fill")
                    
                    Label("**TrollStore** (iOS 14.0–15.4.1 / 15.5 beta / 16.0–16.6.1 / 17.0): Permanent sideloading with no 7-day expiration and no app limits.", systemImage: "2.circle.fill")
                    
                    Label("**Xcode Direct Sideload**: Connect your iPhone with USB-C / Lightning to a Mac running Xcode, select your device, and click Run. Enable 'Developer Mode' under Settings > Privacy & Security.", systemImage: "3.circle.fill")
                }
                .font(.subheadline)
                
                Divider()
                
                Text("Tips for Best Performance:")
                    .font(.headline)
                
                Text("• When downloading 1080p, 1440p, or 4K, YouTube provides separate video and audio streams. The app automatically muxes them using Apple hardware acceleration.\n• Enable 'Auto-Save to Camera Roll' in Settings to view downloaded videos directly in your Photos app alongside your camera recordings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Sideloading Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
