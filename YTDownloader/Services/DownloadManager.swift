import Foundation
import Combine
import UIKit

@MainActor
public final class DownloadManager: NSObject, ObservableObject {
    public static let shared = DownloadManager()
    
    @Published public var downloads: [DownloadItem] = []
    @Published public var isAutoSaveToPhotosEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoSaveToPhotosEnabled, forKey: "autoSaveToPhotos")
        }
    }
    @Published public var selectedEngine: ResolverEngine = .auto {
        didSet {
            UserDefaults.standard.set(selectedEngine.rawValue, forKey: "selectedEngine")
        }
    }
    @Published public var customCobaltEndpoint: String {
        didSet {
            UserDefaults.standard.set(customCobaltEndpoint, forKey: "customCobaltEndpoint")
        }
    }
    
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private let downloadsDirectory: URL
    private let userDefaultsKey = "savedDownloads_v1"
    
    override private init() {
        self.isAutoSaveToPhotosEnabled = UserDefaults.standard.object(forKey: "autoSaveToPhotos") as? Bool ?? true
        if let engineRaw = UserDefaults.standard.string(forKey: "selectedEngine"),
           let engine = ResolverEngine(rawValue: engineRaw) {
            self.selectedEngine = engine
        } else {
            self.selectedEngine = .auto
        }
        self.customCobaltEndpoint = UserDefaults.standard.string(forKey: "customCobaltEndpoint") ?? "https://api.cobalt.tools"
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsDirectory = docs.appendingPathComponent("YTDownloads", isDirectory: true)
        
        super.init()
        
        try? FileManager.default.createDirectory(at: self.downloadsDirectory, withIntermediateDirectories: true)
        loadSavedDownloads()
    }
    
    // MARK: - Persistence
    
    private func loadSavedDownloads() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) else {
            return
        }
        // Verify files still exist on disk
        self.downloads = decoded.map { item in
            var updated = item
            if let fileUrl = updated.localFileUrl, !FileManager.default.fileExists(atPath: fileUrl.path) {
                updated.state = .failed
                updated.errorMessage = "File not found on device"
            }
            return updated
        }
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Download Initiation
    
    public func startDownload(video: VideoMetadata, format: StreamFormat) {
        let isAudioOnly = format.isAudio && !format.isVideo
        let fileExtension = isAudioOnly ? "m4a" : "mp4"
        let safeTitle = sanitizeFileName(video.title)
        let outputFileName = "\(safeTitle)_\(format.qualityLabel)_\(video.id).\(fileExtension)"
        let destinationUrl = downloadsDirectory.appendingPathComponent(outputFileName)
        
        var item = DownloadItem(
            videoId: video.id,
            title: video.title,
            author: video.author,
            thumbnailUrl: video.thumbnailUrl,
            qualityLabel: format.qualityLabel,
            isAudioOnly: isAudioOnly,
            state: .queued,
            progress: 0.0,
            bytesDownloaded: 0,
            totalBytes: format.contentLength ?? 0,
            localFileUrl: destinationUrl
        )
        
        downloads.insert(item, at: 0)
        saveToUserDefaults()
        
        let taskId = item.id
        let task = Task { [weak self] in
            await self?.executeDownload(itemId: taskId, video: video, format: format, destinationUrl: destinationUrl)
        }
        activeTasks[taskId] = task
    }
    
    // MARK: - Download Execution Logic
    
    private func executeDownload(
        itemId: UUID,
        video: VideoMetadata,
        format: StreamFormat,
        destinationUrl: URL
    ) async {
        do {
            if format.isAdaptive && format.isVideo {
                // Adaptive 1080p/4K video stream: Must download video + audio then mux together
                guard let audioFormat = video.bestAudioFormat else {
                    throw MediaMuxer.MuxerError.missingTrack
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let tempVideoUrl = tempDir.appendingPathComponent("\(UUID().uuidString)_v.mp4")
                let tempAudioUrl = tempDir.appendingPathComponent("\(UUID().uuidString)_a.m4a")
                
                defer {
                    try? FileManager.default.removeItem(at: tempVideoUrl)
                    try? FileManager.default.removeItem(at: tempAudioUrl)
                }
                
                // 1. Download Video Track
                updateItem(id: itemId) {
                    $0.state = .downloadingVideo
                    $0.progress = 0.0
                }
                try await downloadStream(
                    streamUrl: format.url,
                    to: tempVideoUrl,
                    itemId: itemId,
                    progressWeight: 0.7,
                    progressBase: 0.0
                )
                
                // 2. Download Audio Track
                updateItem(id: itemId) {
                    $0.state = .downloadingAudio
                }
                try await downloadStream(
                    streamUrl: audioFormat.url,
                    to: tempAudioUrl,
                    itemId: itemId,
                    progressWeight: 0.2,
                    progressBase: 0.7
                )
                
                // 3. Mux Video + Audio with AVFoundation
                updateItem(id: itemId) {
                    $0.state = .muxing
                    $0.progress = 0.92
                }
                try await MediaMuxer.shared.merge(
                    videoUrl: tempVideoUrl,
                    audioUrl: tempAudioUrl,
                    outputUrl: destinationUrl
                ) { [weak self] muxProgress in
                    Task { @MainActor [weak self] in
                        self?.updateItem(id: itemId) {
                            $0.progress = 0.90 + (muxProgress * 0.08)
                        }
                    }
                }
                
            } else {
                // Progressive stream (standard video+audio) or audio-only: Direct single download
                updateItem(id: itemId) {
                    $0.state = format.isVideo ? .downloadingVideo : .downloadingAudio
                    $0.progress = 0.0
                }
                try await downloadStream(
                    streamUrl: format.url,
                    to: destinationUrl,
                    itemId: itemId,
                    progressWeight: 0.95,
                    progressBase: 0.0
                )
            }
            
            // 4. Optionally save to Photos (Camera Roll)
            if isAutoSaveToPhotosEnabled && !format.isAudio {
                updateItem(id: itemId) {
                    $0.state = .savingToPhotos
                    $0.progress = 0.98
                }
                try? await PhotoLibraryManager.shared.saveVideoToCameraRoll(fileUrl: destinationUrl)
            }
            
            // 5. Completion
            updateItem(id: itemId) {
                $0.state = .completed
                $0.progress = 1.0
                $0.speedBytesPerSecond = 0
            }
            saveToUserDefaults()
            
        } catch {
            if Task.isCancelled {
                updateItem(id: itemId) {
                    $0.state = .cancelled
                    $0.errorMessage = "Download cancelled"
                }
            } else {
                updateItem(id: itemId) {
                    $0.state = .failed
                    $0.errorMessage = error.localizedDescription
                }
            }
            saveToUserDefaults()
        }
        
        activeTasks.removeValue(forKey: itemId)
    }
    
    // MARK: - Stream Streaming & Progress Tracking
    
    private func downloadStream(
        streamUrl: URL,
        to destinationUrl: URL,
        itemId: UUID,
        progressWeight: Double,
        progressBase: Double
    ) async throws {
        var request = URLRequest(url: streamUrl)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw YouTubeExtractor.ExtractorError.networkError("Server returned code \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : 0
        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            try? FileManager.default.removeItem(at: destinationUrl)
        }
        
        FileManager.default.createFile(atPath: destinationUrl.path, contents: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: destinationUrl) else {
            throw YouTubeExtractor.ExtractorError.parseError("Could not open file handle for writing")
        }
        defer {
            try? fileHandle.close()
        }
        
        var downloadedBytes: Int64 = 0
        var lastUpdateTime = Date()
        var lastSpeedBytes: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(65536) // 64KB buffer
        
        for try await byte in bytes {
            if Task.isCancelled {
                throw MediaMuxer.MuxerError.cancelled
            }
            
            buffer.append(byte)
            downloadedBytes += 1
            
            if buffer.count >= 65536 {
                try fileHandle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                
                let now = Date()
                let elapsed = now.timeIntervalSince(lastUpdateTime)
                if elapsed >= 0.3 { // Update UI every 300ms
                    let speed = Double(downloadedBytes - lastSpeedBytes) / elapsed
                    let subProgress = expectedLength > 0 ? (Double(downloadedBytes) / Double(expectedLength)) : 0.0
                    let overallProgress = progressBase + (subProgress * progressWeight)
                    
                    updateItem(id: itemId) {
                        $0.progress = min(max(overallProgress, 0.0), 0.99)
                        $0.bytesDownloaded = downloadedBytes
                        $0.totalBytes = expectedLength
                        $0.speedBytesPerSecond = speed
                    }
                    
                    lastUpdateTime = now
                    lastSpeedBytes = downloadedBytes
                }
            }
        }
        
        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
        }
    }
    
    // MARK: - Actions
    
    public func cancelDownload(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        updateItem(id: id) {
            $0.state = .cancelled
        }
        saveToUserDefaults()
    }
    
    public func deleteDownload(item: DownloadItem) {
        cancelDownload(id: item.id)
        if let fileUrl = item.localFileUrl, FileManager.default.fileExists(atPath: fileUrl.path) {
            try? FileManager.default.removeItem(at: fileUrl)
        }
        downloads.removeAll(where: { $0.id == item.id })
        saveToUserDefaults()
    }
    
    public func saveExistingToCameraRoll(item: DownloadItem) async throws {
        guard let url = item.localFileUrl, FileManager.default.fileExists(atPath: url.path) else {
            throw YouTubeExtractor.ExtractorError.parseError("File does not exist")
        }
        try await PhotoLibraryManager.shared.saveVideoToCameraRoll(fileUrl: url)
    }
    
    private func updateItem(id: UUID, block: (inout DownloadItem) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        block(&downloads[index])
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>| \n\t")
        let clean = name.components(separatedBy: invalidCharacters).filter { !$0.isEmpty }.joined(separator: "_")
        return String(clean.prefix(50))
    }
}
