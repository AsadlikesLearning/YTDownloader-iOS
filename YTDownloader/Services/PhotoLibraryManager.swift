import Foundation
import Photos
import UIKit

/// Manages permissions and saving downloaded videos directly to the iOS Photos Library (Camera Roll).
public final class PhotoLibraryManager {
    public static let shared = PhotoLibraryManager()
    
    private init() {}
    
    public enum PhotoError: LocalizedError {
        case accessDenied
        case accessRestricted
        case saveFailed(String)
        case albumCreationFailed
        
        public var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Photo Library access was denied. Please allow access in Settings > YTDownloader."
            case .accessRestricted:
                return "Photo Library access is restricted on this device."
            case .saveFailed(let reason):
                return "Failed to save video to Photos: \(reason)"
            case .albumCreationFailed:
                return "Could not create 'YTDownloader' album in Photos."
            }
        }
    }
    
    /// Requests photo library authorization (add only or read/write)
    public func requestAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Saves a video file at `fileUrl` to the user's Photos library and groups it in a custom album "YTDownloader".
    public func saveVideoToCameraRoll(fileUrl: URL, albumName: String = "YTDownloader") async throws {
        guard await requestAuthorization() else {
            throw PhotoError.accessDenied
        }
        
        // Find or create the album
        let album = try await getOrCreateAlbum(title: albumName)
        
        try await PHPhotoLibrary.shared().performChanges {
            guard let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl) else {
                return
            }
            guard let album = album,
                  let placeholder = assetChangeRequest.placeholderForCreatedAsset,
                  let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                return
            }
            let fastEnumeration = NSArray(array: [placeholder])
            albumChangeRequest.addAssets(fastEnumeration)
        }
    }
    
    private func getOrCreateAlbum(title: String) async throws -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", title)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let existing = collections.firstObject {
            return existing
        }
        
        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            placeholder = request.placeholderForCreatedAssetCollection
        }
        
        guard let localIdentifier = placeholder?.localIdentifier else {
            return nil
        }
        
        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localIdentifier], options: nil)
        return result.firstObject
    }
}
