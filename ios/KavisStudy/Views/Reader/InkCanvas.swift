import SwiftUI
import PencilKit

/// A drawing layer over one page card. With `drawing on` the student writes (Apple Pencil or finger, the system tool
/// picker has pen / marker / eraser / undo); otherwise the notes are only shown and the touches go to the page.
/// The drawing is kept in the shared format (`InkStroke`), so it fits the card at any size and shows on the web too.
struct InkCanvas: UIViewRepresentable {
    let page: InkPage
    let writing: Bool
    let inkColor: UIColor
    let onChange: ([InkStroke]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> InkCanvasView {
        let view = InkCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.isScrollEnabled = false
        view.delegate = context.coordinator
        view.onStrokes = { context.coordinator.parent.onChange($0) }
        // The tool picker watches the canvas from the start: adding it while a line begins cancels that line.
        context.coordinator.watch(view)
        view.show(page)
        return view
    }

    func updateUIView(_ view: InkCanvasView, context: Context) {
        context.coordinator.parent = self
        view.isUserInteractionEnabled = writing
        // A new tool cancels the line being drawn, so it is set only when the paper colour changes.
        if context.coordinator.inkColor != inkColor {
            context.coordinator.inkColor = inkColor
            view.tool = PKInkingTool(.pen, color: inkColor, width: 3)
        }
        view.show(page)
        if !writing { view.resignFirstResponder() }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: InkCanvas
        private let picker = PKToolPicker()
        var inkColor: UIColor?
        init(_ parent: InkCanvas) { self.parent = parent }

        func watch(_ view: PKCanvasView) { picker.addObserver(view) }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            (canvasView as? InkCanvasView)?.drawingNow = true
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            (canvasView as? InkCanvasView)?.drawingNow = false
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            (canvasView as? InkCanvasView)?.changed()
        }
    }
}
