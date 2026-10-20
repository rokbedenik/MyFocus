import AppKit
import SwiftUI

// Transparent AppKit view: a left mouse-down on it drags the whole window,
// a right click shows the app menu (same items as the menu bar)
struct DragHandle: NSViewRepresentable {
    var onContextMenu: ((NSView, NSEvent) -> Void)?

    func makeNSView(context: Context) -> DragView {
        let v = DragView()
        v.onContextMenu = onContextMenu
        return v
    }

    func updateNSView(_ nsView: DragView, context: Context) {
        nsView.onContextMenu = onContextMenu
    }

    final class DragView: NSView {
        var onContextMenu: ((NSView, NSEvent) -> Void)?

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func rightMouseDown(with event: NSEvent) {
            onContextMenu?(self, event)
        }
    }
}
