import SwiftUI
import AVKit

struct IntroAnimationView: View {
    @Binding var isShowing: Bool
    @State private var player: AVPlayer?
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            Color(hex: "070707").ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .ignoresSafeArea()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear {
            guard let url = Bundle.main.url(forResource: "wyldeself-intro", withExtension: "mp4") else {
                #if DEBUG
                print("[Intro] Video not found in bundle")
                #endif
                isShowing = false
                return
            }
            let p = AVPlayer(url: url)
            p.play()
            player = p

            // Watch for video end
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                withAnimation(.easeOut(duration: 0.5)) {
                    fadeOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isShowing = false
                }
            }

            // Fallback: dismiss after 7 seconds in case notification doesn't fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                if isShowing {
                    withAnimation(.easeOut(duration: 0.5)) { fadeOut = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { isShowing = false }
                }
            }
        }
    }
}
