import SwiftUI

struct LibraryView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var filterSegment: Int = 0 // 0: All, 1: Videos, 2: Audio
    @State private var selectedVideoToPlay: DownloadItem?
    @State private var itemToShare: URL?
    @State private var showingSavedToast: Bool = false
    @State private var toastMessage: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Filter", selection: $filterSegment) {
                    Text("All (\(downloadManager.downloads.count))").tag(0)
                    Text("Videos").tag(1)
                    Text("Audio").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if filteredDownloads.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "folder.badge.minus")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Downloads Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Videos and audio you download will appear here for offline playback.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredDownloads) { item in
                            LibraryItemRow(
                                item: item,
                                onPlay: {
                                    if item.localFileUrl != nil {
                                        selectedVideoToPlay = item
                                    }
                                },
                                onSaveToPhotos: {
                                    saveToPhotos(item)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    downloadManager.deleteDownload(item: item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .fullScreenCover(item: $selectedVideoToPlay) { item in
                if let url = item.localFileUrl {
                    VideoPlayerView(videoUrl: url, title: item.title)
                }
            }
            .overlay(alignment: .bottom) {
                if showingSavedToast {
                    Text(toastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private var filteredDownloads: [DownloadItem] {
        let completed = downloadManager.downloads.filter { $0.state == .completed }
        switch filterSegment {
        case 1:
            return completed.filter { !$0.isAudioOnly }
        case 2:
            return completed.filter { $0.isAudioOnly }
        default:
            return completed
        }
    }
    
    private func saveToPhotos(_ item: DownloadItem) {
        Task {
            do {
                try await downloadManager.saveExistingToCameraRoll(item: item)
                await showToast("Saved to Photos Camera Roll!")
            } catch {
                await showToast("Failed to save: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func showToast(_ msg: String) {
        toastMessage = msg
        withAnimation {
            showingSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showingSavedToast = false
            }
        }
    }
}

struct LibraryItemRow: View {
    let item: DownloadItem
    let onPlay: () -> Void
    let onSaveToPhotos: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail / Icon
            Button(action: onPlay) {
                ZStack {
                    if let thumb = item.thumbnailUrl {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 80, height: 50)
                        .cornerRadius(8)
                        .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 50)
                    }
                    
                    Image(systemName: item.isAudioOnly ? "play.circle.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
            }
            .buttonStyle(.plain)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(item.qualityLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Text(item.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Context Menu Actions (Share & Save to Photos)
            Menu {
                Button(action: onPlay) {
                    Label("Play Offline", systemImage: "play.circle")
                }
                
                if !item.isAudioOnly {
                    Button(action: onSaveToPhotos) {
                        Label("Save to Camera Roll", systemImage: "photo.on.rectangle.angled")
                    }
                }
                
                if let url = item.localFileUrl {
                    ShareLink(item: url) {
                        Label("Share File", systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 4)
    }
}
