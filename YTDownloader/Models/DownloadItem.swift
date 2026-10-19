import Foundation

public enum DownloadState: String, Codable {
    case queued = "Queued"
    case downloadingVideo = "Downloading Video"
    case downloadingAudio = "Downloading Audio"
    case muxing = "Merging Audio & Video"
    case savingToPhotos = "Saving to Photos"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public struct DownloadItem: Identifiable, Codable {
    public let id: UUID
    public let videoId: String
    public let title: String
    public let author: String
    public let thumbnailUrl: URL?
    public let qualityLabel: String
    public let isAudioOnly: Bool
    public var state: DownloadState
    public var progress: Double // 0.0 to 1.0
    public var bytesDownloaded: Int64
    public var totalBytes: Int64
    public var speedBytesPerSecond: Double
    public var localFileUrl: URL?
    public var errorMessage: String?
    public var dateAdded: Date
    
    public init(
        id: UUID = UUID(),
        videoId: String,
        title: String,
        author: String,
        thumbnailUrl: URL?,
        qualityLabel: String,
        isAudioOnly: Bool,
        state: DownloadState = .queued,
        progress: Double = 0.0,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        speedBytesPerSecond: Double = 0.0,
        localFileUrl: URL? = nil,
        errorMessage: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.author = author
        self.thumbnailUrl = thumbnailUrl
        self.qualityLabel = qualityLabel
        self.isAudioOnly = isAudioOnly
        self.state = state
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.localFileUrl = localFileUrl
        self.errorMessage = errorMessage
        self.dateAdded = dateAdded
    }
    
    public var formattedSpeed: String {
        guard speedBytesPerSecond > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speedBytesPerSecond)))/s"
    }
    
    public var formattedProgress: String {
        let percentage = Int(progress * 100)
        return "\(percentage)%"
    }
}
