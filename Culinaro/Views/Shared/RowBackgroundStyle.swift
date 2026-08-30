import SwiftUI

/// Hebt Listen-/Formular-Zeilen sichtbar vom animierten Wiesen-Hintergrund ab —
/// in beiden Farbschemata, nicht nur im Dark Mode (wo `secondarySystemBackground`
/// zufällig genug Kontrast zum hellen Wiesen-Overlay hatte).
extension View {
    func meadowRowBackground() -> some View {
        listRowBackground(Color(.secondarySystemBackground))
    }

    /// Zeigt eine kompakte Fehlerzeile über dem Inhalt, wenn ein Store einen
    /// `syncError` gesetzt hat (z. B. kein iCloud-Account, kein Netz) — ohne
    /// dieses Banner blieb ein fehlgeschlagener CloudKit-Sync für den Nutzer
    /// komplett unsichtbar, da `syncError` bisher nirgends gelesen wurde.
    @ViewBuilder
    func syncErrorBanner(_ message: String?) -> some View {
        if let message {
            VStack(spacing: 0) {
                Label(message, systemImage: "exclamationmark.icloud")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                self
            }
        } else {
            self
        }
    }
}
