import SwiftUI
import UIKit

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
        private func clearEntireTree(startingFrom root: UIView, windowBounds: CGRect) {
            if let window = root as? UIWindow {
                window.backgroundColor = .clear
            }

            for subview in root.subviews {
                if subview is UITabBar {
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
