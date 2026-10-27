import SwiftUI
import PencilKit

/// A drawing layer over one page card. With `drawing on` the student writes (Apple Pencil or finger, the system tool
/// picker has pen / marker / eraser / undo); otherwise the notes are only shown and the touches go to the page.
struct InkCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let writing: Bool
    let inkColor: UIColor
    let onChange: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.isScrollEnabled = false
        view.delegate = context.coordinator
        view.drawing = drawing
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        view.isUserInteractionEnabled = writing
        view.tool = PKInkingTool(.pen, color: inkColor, width: 3)
        if view.drawing != drawing { view.drawing = drawing }
        if !writing { view.resignFirstResponder() }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: InkCanvas
        private let picker = PKToolPicker()
        init(_ parent: InkCanvas) { self.parent = parent }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            picker.addObserver(canvasView)
            picker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChange(canvasView.drawing)
        }
    }
}
