
import SwiftUI
import PDFKit

struct PDFKitPreviewView: View {
    let url: URL
    var body: some View {
        PDFKitRepresentable(url: url)
            .ignoresSafeArea()
    }
}

struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
