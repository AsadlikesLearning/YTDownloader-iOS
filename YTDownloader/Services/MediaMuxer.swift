import Foundation
import AVFoundation

/// Merges separate video and audio streams into a single standard MP4 file using native iOS AVFoundation.
/// This allows downloading 1080p, 1440p, or 4K adaptive DASH streams and producing a clean, hardware-accelerated MP4.
public final class MediaMuxer {
    public static let shared = MediaMuxer()
    
    private init() {}
    
    public enum MuxerError: LocalizedError {
        case missingTrack
        case exportFailed(String)
        case cannotCreateAsset
        case cancelled
        
        public var errorDescription: String? {
            switch self {
            case .missingTrack:
                return "Could not find valid video or audio tracks in the downloaded streams."
            case .exportFailed(let reason):
                return "Failed to merge video and audio: \(reason)"
            case .cannotCreateAsset:
                return "Failed to initialize AVAsset from temporary files."
            case .cancelled:
                return "Muxing was cancelled."
            }
        }
    }
    
    /// Merges a video-only file and an audio-only file into an output MP4 at `outputUrl`.
    public func merge(
        videoUrl: URL,
        audioUrl: URL,
        outputUrl: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        // Remove existing file at destination if present
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            try? FileManager.default.removeItem(at: outputUrl)
        }
        
        let videoAsset = AVURLAsset(url: videoUrl, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let audioAsset = AVURLAsset(url: audioUrl, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        
        let composition = AVMutableComposition()
        
        // 1. Video track
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MuxerError.missingTrack
        }
        
        let loadedVideoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = loadedVideoTracks.first else {
            throw MuxerError.missingTrack
        }
        
        let videoDuration = try await videoAsset.load(.duration)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDuration)
        
        try videoTrack.insertTimeRange(videoTimeRange, of: sourceVideoTrack, at: .zero)
        
        // Preserve transform / orientation if present
        if let transform = try? await sourceVideoTrack.load(.preferredTransform) {
            videoTrack.preferredTransform = transform
        }
        
        // 2. Audio track
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MuxerError.missingTrack
        }
        
        let loadedAudioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard let sourceAudioTrack = loadedAudioTracks.first else {
            throw MuxerError.missingTrack
        }
        
        let audioDuration = try await audioAsset.load(.duration)
        // Trim audio to video duration if audio is longer, or vice versa
        let muxDuration = CMTimeMinimum(videoDuration, audioDuration)
        let audioTimeRange = CMTimeRange(start: .zero, duration: muxDuration)
        
        try audioTrack.insertTimeRange(audioTimeRange, of: sourceAudioTrack, at: .zero)
        
        // 3. Export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw MuxerError.exportFailed("Could not create export session")
        }
        
        exportSession.outputURL = outputUrl
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Progress polling timer while export runs
        let progressTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                if exportSession.status == .exporting {
                    progressHandler?(Double(exportSession.progress))
                }
            }
        }
        
        defer {
            progressTimer.cancel()
        }
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            progressHandler?(1.0)
            return
        case .failed:
            let msg = exportSession.error?.localizedDescription ?? "Unknown export error"
            throw MuxerError.exportFailed(msg)
        case .cancelled:
            throw MuxerError.cancelled
        default:
            throw MuxerError.exportFailed("Export finished with unexpected status: \(exportSession.status.rawValue)")
        }
    }
}
