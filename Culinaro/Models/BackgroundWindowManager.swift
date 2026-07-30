import SwiftUI
import UIKit

/// Identifier, mit dem Listen/Formulare markiert werden, deren Zeilen ihre
/// normale, opake Systemfarbe (weiß im Light Mode, schwarz im Dark Mode)
/// behalten sollen. `clearEntireTree` überspringt jeden Teilbaum, dessen
/// Wurzel-View diesen Identifier trägt, komplett — keine Farbänderung,
/// keine Rekursion hinein. Dadurch bleiben die Zeilen unangetastet, egal wie
/// SwiftUI sie intern rendert (Hosting-Wrapper, direkte Layer-Manipulation
/// etc.), da der Sweep sie schlicht nie erreicht.
///
/// HINWEIS: Bei `List`/`Form` landet dieser Identifier in der Praxis oft
/// nicht auf einer echten `UIView`-Instanz im `subviews`-Baum, sondern nur
/// auf einem internen Accessibility-Proxy, den der Sweep nie sieht. Deshalb
/// gibt es zusätzlich den zuverlässigeren, typbasierten Check auf
/// `UICollectionView`/`UITableView` weiter unten in `clearEntireTree` — das
/// ist der eigentliche Mechanismus, der List/Form-Zeilen heute schützt.
/// Der `accessibilityIdentifier`-Check bleibt als zusätzliche Absicherung
/// bestehen (z. B. falls einzelne View-Hierarchien den Identifier doch auf
/// einer echten View tragen).
enum MeadowOpacityTags {
    static let opaqueContent = "meadow-opaque-content"
}

extension View {
    /// Markiert diese View (typischerweise ein `List` oder `Form`) so, dass
    /// der Hintergrund-Sweep sie und alle ihre Kind-Views komplett in Ruhe
    /// lässt — die Zeilen bleiben opak (weiß/schwarz), während alles
    /// außerhalb weiterhin transparent für die Wiesen-Animation ist.
    func keepingOpaqueBackground() -> some View {
        self.accessibilityIdentifier(MeadowOpacityTags.opaqueContent)
    }
}

@MainActor
final class BackgroundWindowManager {
    static let shared = BackgroundWindowManager()

    private var backgroundWindow: UIWindow?
    private var displayLink: CADisplayLink?
    private weak var trackedMainWindow: UIWindow?

    private init() {}

    func installIfNeeded(from view: UIView, backgroundMode: BackgroundModeManager) {
        if backgroundWindow == nil {
            guard let windowScene = view.window?.windowScene else { return }

            let window = UIWindow(windowScene: windowScene)
            window.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue - 1)
            window.isUserInteractionEnabled = false
            window.backgroundColor = .clear

            let hostingController = UIHostingController(
                rootView: BackgroundLayerView(backgroundMode: backgroundMode)
            )
            hostingController.view.backgroundColor = .clear
            window.rootViewController = hostingController
            window.isHidden = false

            backgroundWindow = window
        }

        guard let mainWindow = view.window, displayLink == nil else { return }

        trackedMainWindow = mainWindow
        clearEntireTree(startingFrom: mainWindow, windowBounds: mainWindow.bounds)

        // CADisplayLink statt Timer: läuft synchron mit jedem
        // Bildschirm-Refresh (60–120 Hz), dadurch ist die Bereinigung
        // praktisch verzögerungsfrei — im Gegensatz zum vorherigen
        // 0,3s-Timer, bei dem neu erzeugte, kurzzeitig opake Views (z. B.
        // beim Tab-Wechsel) sichtbar aufblitzen konnten, bevor der nächste
        // Tick sie transparent gemacht hat.
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func handleDisplayTick() {
        guard let mainWindow = trackedMainWindow else { return }
        clearEntireTree(startingFrom: mainWindow, windowBounds: mainWindow.bounds)
    }

    /// Läuft rekursiv durch den kompletten View-Baum. Ein Präsentations-
        /// Container (`UITransitionView` / `UIDropShadowView`) wird nur dann
        /// bereinigt, wenn er (fast) die komplette Fenstergröße einnimmt — das
        /// ist die Haupt-App-Oberfläche.
        ///
        /// `UIVisualEffectView`s werden anhand ihrer EIGENEN Größe behandelt,
        /// nicht danach, wo im Baum sie liegen: Nur großflächige (nahezu
        /// bildschirmfüllende) Material-Layer werden entfernt — das ist der
        /// opake Hintergrund-Blur, den wir eigentlich meinen. Kleine
        /// `UIVisualEffectView`s (z. B. das Glass-Material eines einzelnen
        /// Toolbar-Buttons) bleiben unangetastet, egal in welchem Container sie
        /// stecken — sonst verlieren Buttons kurzzeitig ihren Material-Effekt
        /// und wirken flach-grau.
        ///
        /// `List`/`Form` sind intern seit iOS 16 immer ein `UICollectionView`
        /// (in älteren Fällen ein `UITableView`). Beide werden komplett
        /// übersprungen — keine Farbänderung, keine Rekursion in ihre Zellen.
        /// Das ist der zuverlässige Mechanismus, der Listen-/Formularzeilen
        /// in ihrer normalen, opaken Systemfarbe (weiß/schwarz) hält, egal
        /// wie SwiftUI sie intern zusammensetzt.
        ///
        /// Zusätzlich wird — als weitere Absicherung — jeder Teilbaum
        /// übersprungen, dessen Wurzel-View `MeadowOpacityTags.opaqueContent`
        /// als `accessibilityIdentifier` trägt (siehe `keepingOpaqueBackground()`).
        private func clearEntireTree(startingFrom root: UIView, windowBounds: CGRect) {
            if let window = root as? UIWindow {
                window.backgroundColor = .clear
            }

            for subview in root.subviews {
                if subview is UITabBar {
                    continue
                }

                // Zuverlässiger Schutz für List/Form: Beide sind intern immer
                // ein UICollectionView bzw. UITableView. Dieser Typ-Check ist
                // die eigentliche Absicherung — anders als der
                // accessibilityIdentifier weiter unten landet er garantiert
                // auf einer echten UIView-Instanz im subviews-Baum.
                if subview is UICollectionView || subview is UITableView {
                    continue
                }

                if subview.accessibilityIdentifier == MeadowOpacityTags.opaqueContent {
                    continue
                }

                let className = String(describing: type(of: subview))
                let looksLikePresentationContainer = className.contains("TransitionView")
                    || className.contains("DropShadowView")

                if looksLikePresentationContainer {
                    let frameInWindow = subview.convert(subview.bounds, to: nil)
                    let isFullScreen = abs(frameInWindow.width - windowBounds.width) < 2
                        && abs(frameInWindow.height - windowBounds.height) < 2

                    if !isFullScreen {
                        // Kleiner als der volle Bildschirm → ein Sheet/Popup.
                        // Komplett überspringen, nicht anfassen, auch nicht
                        // weiter absteigen.
                        continue
                    }
                }

                if let effectView = subview as? UIVisualEffectView {
                    let frameInWindow = effectView.convert(effectView.bounds, to: nil)
                    // Nur großflächige Material-Layer anfassen (mind. 60% der
                    // Fensterbreite/-höhe) — das schließt kleine Button-Materials
                    // zuverlässig aus, unabhängig vom umgebenden Container.
                    let isLargeEnough = frameInWindow.width > windowBounds.width * 0.6
                        && frameInWindow.height > windowBounds.height * 0.6

                    if isLargeEnough {
                        effectView.effect = nil
                        effectView.backgroundColor = .clear
                        effectView.contentView.backgroundColor = .clear
                        // Ohne dies bleibt die jetzt unsichtbare Fläche weiterhin
                        // interaktiv (Standard: isUserInteractionEnabled = true)
                        // und fängt Touches ab, bevor sie den darunterliegenden
                        // Scroll-Gestenerkenner der Liste erreichen — dadurch
                        // ließ sich nur direkt auf einer Zeile scrollen, nicht
                        // im Leerraum dazwischen.
                        effectView.isUserInteractionEnabled = false
                    }
                } else {
                    let isKnownContainer = className.contains("HostingView") || className.contains("Hosting")

                    if isKnownContainer || looksLikePresentationContainer || (subview.backgroundColor != nil && subview.backgroundColor != .clear) {
                        subview.backgroundColor = .clear
                    }
                }

                clearEntireTree(startingFrom: subview, windowBounds: windowBounds)
            }
        
    }
}

private struct BackgroundLayerView: View {
    let backgroundMode: BackgroundModeManager

    var body: some View {
        ZStack {
            MeadowView()
                .opacity(backgroundMode.mode == .meadow ? 1 : 0)
            CookModeAnimationView()
                .opacity(backgroundMode.mode == .cookMode ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct BackgroundWindowInstaller: UIViewRepresentable {
    let backgroundMode: BackgroundModeManager

    func makeUIView(context: Context) -> UIView {
        let marker = UIView()
        marker.isHidden = true
        marker.isUserInteractionEnabled = false

        for delay in [0.0, 0.1, 0.3, 0.6, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak marker] in
                guard let marker else { return }
                BackgroundWindowManager.shared.installIfNeeded(from: marker, backgroundMode: backgroundMode)
            }
        }

        return marker
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        BackgroundWindowManager.shared.installIfNeeded(from: uiView, backgroundMode: backgroundMode)
    }
}
