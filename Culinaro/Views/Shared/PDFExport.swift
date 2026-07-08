import SwiftUI
import UniformTypeIdentifiers

struct PDFExport: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName { $0.filename }
    }
}

@MainActor
enum PDFExporter {
    static func export(_ item: any Cookable) -> PDFExport? {
        let content = PDFContent(item: item).frame(width: 515, alignment: .topLeading)
        let renderer = ImageRenderer(content: content)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }

        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: 595, height: max(842, size.height + 80)))
            context.beginPDFPage([kCGPDFContextMediaBox as String: NSData(bytes: &box, length: MemoryLayout<CGRect>.size)] as CFDictionary)
            context.translateBy(x: 40, y: box.height - 40)
            context.scaleBy(x: 1, y: -1)
            draw(context)
            context.endPDFPage()
        }
        context.closePDF()
        return PDFExport(data: data as Data, filename: sanitized(item.title) + ".pdf")
    }

    private static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return name.components(separatedBy: invalid).joined(separator: "-")
    }
}

private struct PDFContent: View {
    let item: any Cookable

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(item.title).font(.largeTitle.bold())
            if !item.ingredients.isEmpty {
                Text("Zutaten").font(.title2.bold())
                ForEach(Array(item.ingredients.enumerated()), id: \.offset) { _, ingredient in
                    Text("• \(ingredient)")
                }
            }
            Text("Schritte").font(.title2.bold())
            ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).").fontWeight(.semibold)
                    Text(step)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(.bottom, 20)
    }
}
