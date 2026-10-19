import SwiftUI

struct DownloadView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var currentVideo: VideoMetadata?
    @State private var showingFormatSheet: Bool = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - URL Input Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Paste YouTube Link")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                            
                            TextField("https://www.youtube.com/watch?v=...", text: $urlInput)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .submitLabel(.go)
                                .onSubmit {
                                    fetchDetails()
                                }
                            
                            if !urlInput.isEmpty {
                                Button(action: { urlInput = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                        // Action buttons: Paste & Analyze
                        HStack(spacing: 12) {
                            Button(action: pasteFromClipboard) {
                                Label("Paste Clipboard", systemImage: "doc.on.clipboard")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: fetchDetails) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red)
                                        .cornerRadius(10)
                                } else {
                                    Label("Find Video", systemImage: "magnifyingglass")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(urlInput.isEmpty ? Color.gray.opacity(0.4) : Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .disabled(urlInput.isEmpty || isLoading)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(16)
                    
                    // MARK: - Video Metadata Card
                    if let video = currentVideo {
                        VStack(alignment: .leading, spacing: 12) {
                            // Thumbnail with duration overlay
                            ZStack(alignment: .bottomTrailing) {
                                if let thumb = video.thumbnailUrl {
                                    AsyncImage(url: thumb) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable()
                                                .aspectRatio(16/9, contentMode: .fit)
                                                .cornerRadius(12)
                                        default:
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .aspectRatio(16/9, contentMode: .fit)
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                                
                                if video.durationSeconds > 0 {
                                    Text(video.formattedDuration)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                        .padding(8)
                                }
                            }
                            
                            // Info
                            Text(video.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .lineLimit(2)
                            
                            HStack {
                                Label(video.author, systemImage: "person.crop.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let views = video.viewCount, let count = Int(views) {
                                    Text("\(count.formatted()) views")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            // Download Button
                            Button(action: {
                                showingFormatSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                        .font(.title2)
                                    Text("Download Options")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                    }
                    
                    // MARK: - Active & Recent Downloads Section
                    if !activeDownloads.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Downloads")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            ForEach(activeDownloads) { item in
                                DownloadProgressCardView(item: item) {
                                    downloadManager.cancelDownload(id: item.id)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("YT Downloader")
            .sheet(isPresented: $showingFormatSheet) {
                if let video = currentVideo {
                    FormatSelectionSheet(video: video) { selectedFormat in
                        downloadManager.startDownload(video: video, format: selectedFormat)
                        // Trigger haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(errorMessage ?? "Unknown error occurred.")
            })
            .onAppear {
                checkClipboardForYouTubeLink()
            }
        }
    }
    
    private var activeDownloads: [DownloadItem] {
        downloadManager.downloads.filter {
            $0.state != .completed && $0.state != .failed && $0.state != .cancelled
        }
    }
    
    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            urlInput = string.trimmingCharacters(in: .whitespacesAndNewlines)
            fetchDetails()
        }
    }
    
    private func checkClipboardForYouTubeLink() {
        guard urlInput.isEmpty, let string = UIPasteboard.general.string else { return }
        if YouTubeExtractor.shared.extractVideoId(from: string) != nil {
            urlInput = string.trimmingCharacters(in: .whitespacesAndNewlines)
            fetchDetails()
        }
    }
    
    private func fetchDetails() {
        guard !urlInput.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let metadata = try await YouTubeExtractor.shared.fetchVideoDetails(
                    for: urlInput,
                    engine: downloadManager.selectedEngine,
                    customCobaltEndpoint: downloadManager.customCobaltEndpoint
                )
                await MainActor.run {
                    self.currentVideo = metadata
                    self.isLoading = false
                    self.showingFormatSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }
}
