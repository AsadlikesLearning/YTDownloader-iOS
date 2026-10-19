import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoUrl: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView("Loading Video...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: videoUrl) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                let avPlayer = AVPlayer(url: videoUrl)
                self.player = avPlayer
                avPlayer.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }
}
