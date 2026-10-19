import SwiftUI

struct FormatSelectionSheet: View {
    let video: VideoMetadata
    let onSelect: (StreamFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0 // 0: Video, 1: Audio
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header preview
                HStack(spacing: 12) {
                    if let thumb = video.thumbnailUrl {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 90, height: 55)
                        .cornerRadius(8)
                        .clipped()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(2)
                        
                        Text(video.author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if video.durationSeconds > 0 {
                            Text(video.formattedDuration)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                
                Picker("Format Type", selection: $selectedTab) {
                    Text("Video (MP4)").tag(0)
                    Text("Audio Only").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Formats List
                List {
                    if selectedTab == 0 {
                        Section(header: Text("Video Resolutions")) {
                            ForEach(displayVideoFormats, id: \.id) { format in
                                Button(action: {
                                    onSelect(format)
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(format.qualityLabel)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                if isHighestResolution(format) {
                                                    Text("BEST")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Color.green)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(4)
                                                }
                                                
                                                if format.isAdaptive {
                                                    Text("Adaptive + AAC")
                                                        .font(.caption2)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 2)
                                                        .background(Color.blue.opacity(0.12))
                                                        .foregroundColor(.blue)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            
                                            Text("Container: \(format.container.uppercased()) • \(format.formattedSize)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    } else {
                        Section(header: Text("Audio Tracks")) {
                            ForEach(displayAudioFormats, id: \.id) { format in
                                Button(action: {
                                    onSelect(format)
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(format.qualityLabel)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Format: \(format.container.uppercased()) • \(format.formattedSize)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Select Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var displayVideoFormats: [StreamFormat] {
        // Filter out non-video formats and deduplicate by qualityLabel
        var seen = Set<String>()
        var result: [StreamFormat] = []
        for fmt in video.formats where fmt.isVideo {
            if !seen.contains(fmt.qualityLabel) {
                seen.insert(fmt.qualityLabel)
                result.append(fmt)
            }
        }
        return result.isEmpty ? video.formats.filter { $0.isVideo } : result
    }
    
    private var displayAudioFormats: [StreamFormat] {
        video.audioFormats.isEmpty ? video.formats.filter { $0.isAudio } : video.audioFormats
    }
    
    private func isHighestResolution(_ format: StreamFormat) -> Bool {
        return format.id == displayVideoFormats.first?.id
    }
}
