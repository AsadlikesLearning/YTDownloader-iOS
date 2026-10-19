import SwiftUI

struct DownloadProgressCardView: View {
    let item: DownloadItem
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Thumbnail or Icon
                if let thumb = item.thumbnailUrl {
                    AsyncImage(url: thumb) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay {
                                    Image(systemName: item.isAudioOnly ? "music.note" : "play.rectangle")
                                        .foregroundColor(.gray)
                                }
                        }
                    }
                    .frame(width: 60, height: 45)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 45)
                        .overlay {
                            Image(systemName: item.isAudioOnly ? "music.note" : "play.rectangle")
                                .foregroundColor(.gray)
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(item.qualityLabel)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        Text(item.state.rawValue)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                }
                
                Spacer()
                
                if item.state != .completed && item.state != .failed && item.state != .cancelled {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress Bar & Stats
            if item.state != .completed && item.state != .failed && item.state != .cancelled {
                VStack(spacing: 4) {
                    ProgressView(value: item.progress)
                        .tint(Color.red)
                    
                    HStack {
                        Text(item.formattedProgress)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !item.formattedSpeed.isEmpty {
                            Text(item.formattedSpeed)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if let error = item.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        switch item.state {
        case .completed:
            return .green
        case .failed, .cancelled:
            return .red
        case .muxing, .savingToPhotos:
            return .orange
        default:
            return .blue
        }
    }
}
