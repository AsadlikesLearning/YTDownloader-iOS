import Foundation

public enum ResolverEngine: String, CaseIterable, Identifiable {
    case auto = "Auto (Smart Fallback)"
    case innertube = "Direct YouTube (Innertube)"
    case cobalt = "Cobalt Engine (Up to 4K)"
    
    public var id: String { rawValue }
}

public final class YouTubeExtractor {
    public static let shared = YouTubeExtractor()
    
    private init() {}
    
    public enum ExtractorError: LocalizedError {
        case invalidUrl
        case videoIdNotFound
        case videoUnavailable(String)
        case networkError(String)
        case parseError(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidUrl:
                return "The entered link is not a valid YouTube URL."
            case .videoIdNotFound:
                return "Could not extract a YouTube video ID from the provided link."
            case .videoUnavailable(let reason):
                return "Video is unavailable: \(reason)"
            case .networkError(let reason):
                return "Network request failed: \(reason)"
            case .parseError(let reason):
                return "Failed to parse video information: \(reason)"
            }
        }
    }
    
    /// Extracts video ID from standard YouTube URL formats:
    /// - youtube.com/watch?v=...
    /// - youtu.be/...
    /// - youtube.com/shorts/...
    /// - youtube.com/embed/...
    public func extractVideoId(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        
        let host = url.host?.lowercased() ?? ""
        
        // Handle youtu.be/VIDEO_ID
        if host.contains("youtu.be") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let components = path.components(separatedBy: "/")
            if let first = components.first, !first.isEmpty {
                return first
            }
        }
        
        // Handle youtube.com/shorts/VIDEO_ID or /embed/VIDEO_ID
        if host.contains("youtube.com") {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let shortsIdx = pathComponents.firstIndex(of: "shorts"), shortsIdx + 1 < pathComponents.count {
                return pathComponents[shortsIdx + 1]
            }
            if let embedIdx = pathComponents.firstIndex(of: "embed"), embedIdx + 1 < pathComponents.count {
                return pathComponents[embedIdx + 1]
            }
            
            // Standard query param: ?v=VIDEO_ID
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                if let vItem = queryItems.first(where: { $0.name == "v" }) {
                    return vItem.value
                }
            }
        }
        
        // If the user pasted just the 11-char video ID directly
        let idRegex = "^[a-zA-Z0-9_-]{11}$"
        if trimmed.range(of: idRegex, options: .regularExpression) != nil {
            return trimmed
        }
        
        return nil
    }
    
    /// Fetches video details and stream formats using selected engine strategy
    public func fetchVideoDetails(
        for urlString: String,
        engine: ResolverEngine = .auto,
        customCobaltEndpoint: String = "https://api.cobalt.tools"
    ) async throws -> VideoMetadata {
        guard let videoId = extractVideoId(from: urlString) else {
            throw ExtractorError.videoIdNotFound
        }
        
        switch engine {
        case .innertube:
            return try await fetchViaInnertube(videoId: videoId)
        case .cobalt:
            return try await fetchViaCobalt(videoId: videoId, endpoint: customCobaltEndpoint)
        case .auto:
            do {
                return try await fetchViaInnertube(videoId: videoId)
            } catch {
                // Smooth fallback to Cobalt if Innertube is challenged/throttled
                return try await fetchViaCobalt(videoId: videoId, endpoint: customCobaltEndpoint)
            }
        }
    }
    
    // MARK: - Innertube Engine (Direct On-Device API)
    
    private func fetchViaInnertube(videoId: String) async throws -> VideoMetadata {
        let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("101", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("1.02", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        // VisionOS client payload - provides direct unthrottled streaming URLs without JS cipher requirements
        let requestBody: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "VISIONOS",
                    "clientVersion": "1.02",
                    "deviceMake": "Apple",
                    "deviceModel": "RealityDevice17,1",
                    "osName": "visionOS",
                    "osVersion": "26.5.23O471",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "videoId": videoId,
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw ExtractorError.networkError("YouTube server returned status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractorError.parseError("Invalid JSON response from YouTube.")
        }
        
        // Check playabilityStatus
        if let playabilityStatus = json["playabilityStatus"] as? [String: Any],
           let status = playabilityStatus["status"] as? String,
           status != "OK" {
            let reason = playabilityStatus["reason"] as? String ?? "Video cannot be played."
            throw ExtractorError.videoUnavailable(reason)
        }
        
        // Video Details
        guard let videoDetails = json["videoDetails"] as? [String: Any] else {
            throw ExtractorError.parseError("Missing videoDetails in YouTube response.")
        }
        
        let title = videoDetails["title"] as? String ?? "Unknown Title"
        let author = videoDetails["author"] as? String ?? "Unknown Author"
        let lengthSeconds = Int(videoDetails["lengthSeconds"] as? String ?? "0") ?? 0
        let viewCount = videoDetails["viewCount"] as? String
        
        var thumbUrl: URL? = nil
        if let thumbnails = (videoDetails["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
           let bestThumb = thumbnails.last?["url"] as? String {
            thumbUrl = URL(string: bestThumb)
        }
        if thumbUrl == nil {
            thumbUrl = URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
        }
        
        // Streaming Data
        guard let streamingData = json["streamingData"] as? [String: Any] else {
            throw ExtractorError.parseError("No streaming data available for this video.")
        }
        
        var streamFormats: [StreamFormat] = []
        
        // 1. Progressive formats (video + audio in one stream)
        if let formats = streamingData["formats"] as? [[String: Any]] {
            for fmt in formats {
                if let stream = parseStreamFormat(fmt, isAdaptive: false) {
                    streamFormats.append(stream)
                }
            }
        }
        
        // 2. Adaptive formats (high-res separate video & audio)
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            for fmt in adaptiveFormats {
                if let stream = parseStreamFormat(fmt, isAdaptive: true) {
                    streamFormats.append(stream)
                }
            }
        }
        
        // Sort formats: video formats descending by quality, then audio formats
        let sortedFormats = streamFormats.sorted { a, b in
            if a.isVideo && b.isVideo {
                return (a.bitrate ?? 0) > (b.bitrate ?? 0)
            }
            if a.isVideo != b.isVideo {
                return a.isVideo
            }
            return (a.bitrate ?? 0) > (b.bitrate ?? 0)
        }
        
        return VideoMetadata(
            id: videoId,
            title: title,
            author: author,
            durationSeconds: lengthSeconds,
            thumbnailUrl: thumbUrl,
            viewCount: viewCount,
            formats: sortedFormats
        )
    }
    
    private func parseStreamFormat(_ dict: [String: Any], isAdaptive: Bool) -> StreamFormat? {
        guard let urlString = dict["url"] as? String,
              let url = URL(string: urlString),
              let itag = dict["itag"] as? Int,
              let mimeType = dict["mimeType"] as? String else {
            return nil
        }
        
        let isVideo = mimeType.contains("video/")
        let isAudio = mimeType.contains("audio/")
        
        let qualityLabel: String
        if let ql = dict["qualityLabel"] as? String {
            qualityLabel = ql
        } else if isAudio {
            let bitrate = (dict["bitrate"] as? Int ?? 128000) / 1000
            qualityLabel = "Audio \(bitrate)k"
        } else {
            qualityLabel = dict["quality"] as? String ?? "Standard"
        }
        
        let contentLengthStr = dict["contentLength"] as? String
        let contentLength = contentLengthStr.flatMap { Int64($0) }
        let bitrate = dict["bitrate"] as? Int
        
        let container: String
        if mimeType.contains("mp4") {
            container = "mp4"
        } else if mimeType.contains("webm") {
            container = "webm"
        } else if mimeType.contains("m4a") {
            container = "m4a"
        } else {
            container = "mp4"
        }
        
        // Prefer standard MP4/H.264/AAC for iOS compatibility
        return StreamFormat(
            id: "\(itag)_\(qualityLabel)",
            itag: itag,
            qualityLabel: qualityLabel,
            mimeType: mimeType,
            isVideo: isVideo,
            isAudio: isAudio,
            isAdaptive: isAdaptive,
            url: url,
            contentLength: contentLength,
            bitrate: bitrate,
            container: container
        )
    }
    
    // MARK: - Cobalt API Fallback Engine (Reliable up to 4K / MP3)
    
    private func fetchViaCobalt(videoId: String, endpoint: String) async throws -> VideoMetadata {
        let videoUrl = "https://www.youtube.com/watch?v=\(videoId)"
        guard let url = URL(string: "\(endpoint)/") else {
            throw ExtractorError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload: [String: Any] = [
            "url": videoUrl,
            "videoQuality": "max",
            "youtubeVideoCodec": "h264"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw ExtractorError.networkError("Resolver API returned error \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractorError.parseError("Failed to parse resolver API response")
        }
        
        // Cobalt returns status: "stream" or "redirect" with a direct download url
        guard let streamUrlString = json["url"] as? String,
              let directStreamUrl = URL(string: streamUrlString) else {
            let text = json["text"] as? String ?? "Resolver could not produce a download URL"
            throw ExtractorError.videoUnavailable(text)
        }
        
        let title = json["filename"] as? String ?? "YouTube Video (\(videoId))"
        let thumb = URL(string: "https://i.ytimg.com/vi/\(videoId)/maxresdefault.jpg")
            ?? URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")
        
        // Construct synthesized high quality formats from Cobalt
        let formats: [StreamFormat] = [
            StreamFormat(
                id: "cobalt_best",
                itag: 1080,
                qualityLabel: "Best Available (Up to 1080p/4K)",
                mimeType: "video/mp4",
                isVideo: true,
                isAudio: true,
                isAdaptive: false,
                url: directStreamUrl,
                contentLength: nil,
                bitrate: 4500000,
                container: "mp4"
            ),
            StreamFormat(
                id: "cobalt_audio",
                itag: 140,
                qualityLabel: "Audio (Original M4A/MP3)",
                mimeType: "audio/mp4",
                isVideo: false,
                isAudio: true,
                isAdaptive: false,
                url: directStreamUrl,
                contentLength: nil,
                bitrate: 192000,
                container: "m4a"
            )
        ]
        
        return VideoMetadata(
            id: videoId,
            title: title,
            author: "YouTube",
            durationSeconds: 0,
            thumbnailUrl: thumb,
            viewCount: nil,
            formats: formats
        )
    }
}
