import SwiftUI
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        // Make the player view background transparent so the app gradient shows through
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.contentOverlayView?.wantsLayer = true
        view.contentOverlayView?.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
