import SwiftUI
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeNSView(context: Context) -> AVPlayerView {
        let view = TransparentPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        view.videoGravity = videoGravity
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
        if nsView.videoGravity != videoGravity {
            nsView.videoGravity = videoGravity
        }
    }
}

/// AVPlayerView subclass that forces a transparent background
/// by clearing the background color of all internal sublayers.
final class TransparentPlayerView: AVPlayerView {
    override func layout() {
        super.layout()
        clearBlackBackground(in: self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        clearBlackBackground(in: self)
    }

    private func clearBlackBackground(in view: NSView) {
        view.wantsLayer = true
        if let layer = view.layer {
            // Clear black backgrounds but preserve the actual video layer
            if layer.backgroundColor == NSColor.black.cgColor ||
               layer.backgroundColor == CGColor.black {
                layer.backgroundColor = CGColor.clear
            }
            clearSublayers(layer)
        }
        for subview in view.subviews {
            clearBlackBackground(in: subview)
        }
    }

    private func clearSublayers(_ layer: CALayer) {
        guard let sublayers = layer.sublayers else { return }
        for sublayer in sublayers {
            // Don't touch AVPlayerLayer itself — only clear backing layers
            if !(sublayer is AVPlayerLayer) {
                if sublayer.backgroundColor == NSColor.black.cgColor ||
                   sublayer.backgroundColor == CGColor.black {
                    sublayer.backgroundColor = CGColor.clear
                }
            }
            clearSublayers(sublayer)
        }
    }
}
