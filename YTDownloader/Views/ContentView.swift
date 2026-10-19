import SwiftUI

struct ContentView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DownloadView()
                .tabItem {
                    Label("Downloader", systemImage: "arrow.down.circle.fill")
                }
                .tag(0)
            
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "play.rectangle.on.rectangle.fill")
                }
                .badge(completedCount)
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.red)
    }
    
    private var completedCount: Int {
        downloadManager.downloads.filter { $0.state == .completed }.count
    }
}

#Preview {
    ContentView()
}
