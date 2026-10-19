# YTDownloader for iOS (Sideload Edition) 📱

A native, lightweight, and high-performance YouTube video & audio downloader app designed specifically for iOS (iPhone & iPad). Built in 100% native SwiftUI and AVFoundation, optimized for sideloading directly to your personal device.

---

## ✨ Features

- ⚡ **Full HD & 4K Downloads**: Download videos up to 1080p and 4K with crystal clear AAC audio.
- 🎵 **Audio Extraction**: Download YouTube videos as standalone M4A audio tracks for offline listening.
- 🎞️ **Native AVFoundation Muxing**: Automatically merges adaptive video-only and audio-only streams into standard MP4 format using Apple's built-in hardware acceleration—zero external dependencies or heavy FFmpeg binaries required.
- 📸 **Camera Roll Integration**: Directly save downloaded videos into your iPhone's **Photos** app under a dedicated `YTDownloader` album with a single tap (or automatically upon download completion).
- 🎬 **Built-in Offline Player**: Play saved videos in full screen with scrubber, picture-in-picture, and AirPlay support.
- 📋 **Smart Clipboard Detection**: Automatically detects YouTube links from your pasteboard upon opening the app.
- 🔁 **Dual-Engine Resolver**:
  - **Direct Innertube (On-Device)**: Directly talks to YouTube's Innertube API for high speed.
  - **Cobalt Engine Fallback**: Resolves cipher signatures and n-parameter challenges up to 4K, with customizable API endpoints in Settings.
- 📤 **iOS Share Sheet & Files**: Open downloaded media in VLC, Infuse, WhatsApp, Telegram, or AirDrop to your Mac/iPad.

---

## 📁 Project Architecture

```
YTDownloader-iOS/
├── YTDownloader.xcodeproj/         # Xcode project configuration
└── YTDownloader/
    ├── App/
    │   └── YTDownloaderApp.swift   # Main SwiftUI App entry point
    ├── Models/
    │   ├── VideoMetadata.swift     # Video metadata & format descriptors
    │   └── DownloadItem.swift      # Download queue item & state tracking
    ├── Services/
    │   ├── YouTubeExtractor.swift  # Innertube & Cobalt stream resolvers
    │   ├── DownloadManager.swift   # URLSession downloader with speed/progress
    │   ├── MediaMuxer.swift        # Native AVAssetExportSession video+audio muxer
    │   └── PhotoLibraryManager.swift # PHPhotoLibrary Camera Roll exporter
    ├── Views/
    │   ├── ContentView.swift       # TabView navigation container
    │   ├── DownloadView.swift      # Main URL input, metadata preview & download UI
    │   ├── FormatSelectionSheet.swift # Resolution & audio picker modal
    │   ├── DownloadProgressCardView.swift # Live animated progress card
    │   ├── LibraryView.swift       # Offline library with delete, share & playback
    │   ├── VideoPlayerView.swift   # AVPlayer full-screen player
    │   └── SettingsView.swift      # Auto-save, resolver engine, and storage cleaner
    └── Resources/
        └── Info.plist              # Permissions (Camera Roll, Background, Sharing)
```

---

## 📲 How to Sideload onto Your iPhone

Because Apple App Store guidelines restrict YouTube download utilities, this app is built for direct sideloading onto your personal iPhone. Choose the installation method that fits your setup:

### Method 1: Xcode Direct Install (Recommended if you have a Mac)

1. Open `YTDownloader.xcodeproj` in **Xcode**.
2. Connect your iPhone to your Mac via USB-C or Lightning cable.
3. In Xcode's top target bar, select your connected iPhone.
4. Go to **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Select your personal Apple ID under **Team** (a free Apple Developer account works).
   - Change the Bundle Identifier slightly if needed (e.g. `com.yourname.ytdownloader`).
5. Press **Cmd + R** (Run).
6. On your iPhone:
   - Go to **Settings > Privacy & Security > Developer Mode** and turn it **ON** (iOS will reboot).
   - Go to **Settings > General > VPN & Device Management**, tap your Apple ID, and tap **Trust**.
7. Launch **YT Downloader** on your home screen!

---

### Method 2: Sideloadly / AltStore / SideStore (Windows or Mac)

1. **Build the `.ipa` or Archive in Xcode**:
   - In Xcode: `Product > Archive` -> `Distribute App` -> `Development` / `Ad Hoc` -> Export as `.ipa`.
2. **Install using Sideloadly (Works on Windows & Mac)**:
   - Download [Sideloadly](https://sideloadly.io/).
   - Connect your iPhone to your PC.
   - Drag the `YTDownloader.ipa` into Sideloadly.
   - Enter your Apple ID and click **Start**.
   - Once installed, trust your certificate under **Settings > General > VPN & Device Management**.
3. **Using SideStore / AltStore**:
   - Open SideStore or AltStore on your iPhone.
   - Tap **+** and choose `YTDownloader.ipa` to sign and install wirelessly.

---

### Method 3: TrollStore (For compatible iOS 14.0 - 17.0 devices)

If your iPhone is running an iOS version supported by TrollStore:
1. Export or download `YTDownloader.tipa` or `YTDownloader.ipa`.
2. Share the file to TrollStore.
3. Tap **Install**.
4. The app is permanently signed with root entitlements—no 7-day expiration, no revokes, and no PC required!

---

## ⚙️ Configuration & Tips

- **Auto-Save to Camera Roll**: Go to the **Settings** tab in the app and enable *Auto-Save to Camera Roll*. Any downloaded video will instantly appear in the iOS Photos app in your camera roll.
- **Cobalt Endpoint**: In Settings, the resolver defaults to `https://api.cobalt.tools`. You can also configure a self-hosted instance if preferred.
- **Document Sharing**: The app has `UIFileSharingEnabled` turned on. You can connect your iPhone to a Mac or PC and copy your downloaded videos directly through Finder / iTunes or the iOS **Files** app (`On My iPhone > YTDownloader`).
