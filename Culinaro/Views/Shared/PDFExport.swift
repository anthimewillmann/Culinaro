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
        return render(content, filename: sanitized(item.title) + ".pdf")
    }

    static func export(_ items: [any Cookable], filename: String) -> PDFExport? {
        guard !items.isEmpty else { return nil }
        let content = PDFCollectionContent(items: items).frame(width: 515, alignment: .topLeading)
        return render(content, filename: sanitized(filename) + ".pdf")
    }

    private static func render<Content: View>(_ content: Content, filename: String) -> PDFExport? {
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
        return PDFExport(data: data as Data, filename: filename)
    }

    private static func sanitized(_ name: String) -> String {
        // Titles can come from AI-scanned/generated text (which may contain
        // newlines the model didn't fully clean up), so control characters
        // and whitespace runs must be collapsed too, not just filesystem
        // punctuation — otherwise a raw newline/tab survives into the
        // suggested filename and some share targets reject or mangle it.
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
            .union(.controlCharacters)
        let collapsed = name.components(separatedBy: invalid).joined(separator: "-")
        return collapsed
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct PDFContent: View {
    let item: any Cookable

    var body: some View {
        cookableContent(item)
            .foregroundStyle(.black)
            .padding(.bottom, 20)
    }
}

private struct PDFCollectionContent: View {
    let items: [any Cookable]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                cookableContent(item)

                if index < items.count - 1 {
                    Divider()
                        .overlay(.black.opacity(0.25))
                }
            }
        }
        .foregroundStyle(.black)
        .padding(.bottom, 20)
    }
}

@ViewBuilder
private func cookableContent(_ item: any Cookable) -> some View {
    VStack(alignment: .leading, spacing: 18) {
        Text(item.title).font(.largeTitle.bold())
        if !item.ingredients.isEmpty {
            Text("ingredients").font(.title2.bold())
            ForEach(Array(item.ingredients.enumerated()), id: \.offset) { _, ingredient in
                Text("• \(ingredient)")
            }
        }
        Text("steps").font(.title2.bold())
        ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top) {
                Text("\(index + 1).").fontWeight(.semibold)
                Text(step)
            }
        }
    }
}
