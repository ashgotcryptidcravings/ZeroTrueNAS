import SwiftUI
import PDFKit

struct PDFViewerView: View {
    @Environment(\.dismiss) var dismiss

    let data: Data
    let filename: String

    @State private var currentPage = 0
    @State private var totalPages = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .glassEffect(.regular, in: .circle)
                    }

                    Spacer()

                    Text(filename)
                        .font(Theme.monoFont(13))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if totalPages > 0 {
                        Text("\(currentPage + 1)/\(totalPages)")
                            .font(Theme.monoFont(12))
                            .foregroundColor(Theme.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(Theme.cyan.opacity(0.05)), in: .capsule)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // PDF content
                PDFKitView(data: data, currentPage: $currentPage, totalPages: $totalPages)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    @Binding var currentPage: Int
    @Binding var totalPages: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(Theme.background)

        if let document = PDFDocument(data: data) {
            pdfView.document = document
            DispatchQueue.main.async {
                totalPages = document.pageCount
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    class Coordinator: NSObject {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document,
                  let pageIndex = document.index(for: currentPage) as Int? else { return }
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
}
