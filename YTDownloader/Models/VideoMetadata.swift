import Foundation

public struct StreamFormat: Identifiable, Hashable {
    public let id: String
    public let itag: Int
    public let qualityLabel: String
    public let mimeType: String
    public let isVideo: Bool
    public let isAudio: Bool
    public let isAdaptive: Bool // Video-only or Audio-only stream
    public let url: URL
    public let contentLength: Int64?
    public let bitrate: Int?
    public let container: String
    
    public var formattedSize: String {
        guard let bytes = contentLength, bytes > 0 else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    public var displayName: String {
        if isVideo && isAudio {
            return "\(qualityLabel) (Video + Audio) - \(formattedSize)"
        } else if isVideo {
            return "\(qualityLabel) HD (Video Only) - \(formattedSize)"
        } else if isAudio {
            let kbps = (bitrate ?? 128000) / 1000
            return "Audio Only (\(kbps) kbps \(container.uppercased())) - \(formattedSize)"
        }
        return "\(qualityLabel) - \(formattedSize)"
    }
}

public struct VideoMetadata: Identifiable, Hashable {
    public let id: String // YouTube Video ID
    public let title: String
    public let author: String
    public let durationSeconds: Int
    public let thumbnailUrl: URL?
    public let viewCount: String?
    public let formats: [StreamFormat]
    
    public var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    public var progressiveFormats: [StreamFormat] {
        formats.filter { $0.isVideo && $0.isAudio }
    }
    
    public var videoOnlyFormats: [StreamFormat] {
        formats.filter { $0.isVideo && !$0.isAudio }
    }
    
    public var audioFormats: [StreamFormat] {
        formats.filter { $0.isAudio }
    }
    
    public var bestAudioFormat: StreamFormat? {
        audioFormats.max(by: { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) })
    }
}
