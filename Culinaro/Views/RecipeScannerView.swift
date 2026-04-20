import SwiftUI

struct RecipeScannerView: View {
    @Binding var title: String
    @Binding var ingredients: [TextRow]
    @Binding var steps: [TextRow]

    var body: some View {
        Label(NSLocalizedString("scanner_add_photo", comment: ""), systemImage: "camera.fill")
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .foregroundStyle(.tint)
    }
}
