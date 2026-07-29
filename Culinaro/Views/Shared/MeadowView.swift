import SwiftUI

// MARK: - Änderungen gegenüber der Vorversion
//
// 1. SnowfallView zeichnet Flocken jetzt gebündelt nach Deckkraft-Buckets
//    (statt eines context.fill() pro Flocke) → deutlich weniger Draw-Calls
//    bei mehreren tausend Flocken.
// 2. Die Animationssequenzen (Intro + Loop) sind jetzt deklarative
//    [SequenceStep]-Arrays statt einer langen Kette aus
//    `try? await Task.sleep` + `withAnimation`.
// 3. `.onAppear` wurde durch `.task` ersetzt; zusammen mit expliziten
//    Cancellation-Checks bricht die Sequenz sauber ab, wenn die View aus
//    der Hierarchie verschwindet, statt unbeobachtet weiterzulaufen.
// 4. Magic Numbers (Zoomfaktor, Schneemann-Sinkstrecke, Hügelhöhen) stehen
//    jetzt benannt in `AnimationConstants`.
// 5. `resetAllStatesForIntro()` und `resetLoopStartStates()` wurden zu
//    einer gemeinsamen Funktion mit Parameter zusammengeführt.
// 6. Die Anchor-Preference-Auswertung nutzt statt `DispatchQueue.main.async`
//    das modernere `Task { @MainActor in ... }`.

/// Übermittelt die Bildschirmposition eines Markerpunkts (Mitte eines roten
/// Kuppel-Segments am Sonnenschirm) durch die View-Hierarchie nach oben, damit
/// `MeadowView` daraus einen exakten, tatsächlich gemessenen Zoom-Ankerpunkt
/// bestimmen kann – unabhängig von Safe-Area- oder Layout-Eigenheiten.
private struct RedCanopyAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

/// Benannte Konstanten für Werte, die vorher als "magic numbers" direkt in
/// der Animationssequenz standen. Erleichtert das Anpassen und Verstehen der
/// Kernparameter, ohne die Sequenz selbst durchsuchen zu müssen.
private enum AnimationConstants {
    /// Ziel-Zoomfaktor beim Hineinzoomen in den roten Schirm-Marker.
    static let umbrellaZoomTargetScale: CGFloat = 45
    /// Strecke, um die der Schneemann am Ende der Winterszene nach unten sinkt.
    static let snowmanSinkDistance: CGFloat = 260
    /// Hügelhöhe der Winterszene direkt nach dem weißen Wisch (vor dem Wachsen).
    static let initialWinterHillHeightFraction: CGFloat = 0.36
    /// Zielhöhe des Wintergrund-Hügels: identisch zur grünen Anfangsfläche.
    static let summerHillHeightFraction: CGFloat = 0.55
}

/// Ein einzelner Schritt einer Animationssequenz. Die gesamte Zeitleiste
/// einer Sequenz lässt sich damit als flaches, gut lesbares Array
/// beschreiben, anstatt als lange Kette von
/// `try? await Task.sleep(...)` + `withAnimation { ... }`-Aufrufen, bei der
/// man die Summe aller Wartezeiten manuell nachzählen muss.
private enum SequenceStep {
    /// Wartet die angegebene Anzahl Sekunden, bevor der nächste Schritt beginnt.
    case wait(Double)
    /// Führt eine Zustandsänderung mit der angegebenen Animation aus.
    case animate(Animation, () -> Void)
    /// Führt eine Zustandsänderung ohne Animation aus (z. B. beim verdeckten
    /// Szenenwechsel während des weißen Wisches).
    case instant(() -> Void)
    /// Führt eine eigene asynchrone Teil-Sequenz aus, z. B. eine schrittweise
    /// Intensitätsänderung über mehrere Sekunden.
    case custom(() async -> Void)
}

/// Eine Wiesen-Szene, die am Ende der Animation in einen Herbstwald und
/// anschließend eine Winterszene übergeht.
///
/// Ablauf:
/// 1. Einmaliges Intro: Standardhintergrund (weiß/schwarz) wird zu Blau,
///    danach fährt die grüne Fläche hoch.
/// 2. Ab da läuft die restliche Sequenz (Blumen, Berge, Strand, Herbst,
///    Winter, Schneemann versinkt, Fläche wächst & wird grün) als
///    Endlos-Loop, der immer wieder genau dort beginnt, wo er endet:
///    blauer Himmel + grüne Fläche.
struct MeadowView: View {
    // MARK: - State
    @State private var skyOpacity: CGFloat = 0
    @State private var hillRise: CGFloat = 0
    @State private var flowersOpacity: CGFloat = 0
    @State private var mountainsRise: CGFloat = 0
    @State private var waveRise: CGFloat = 0
    @State private var sandOverlayOpacity: CGFloat = 0
    @State private var deepBlueRise: CGFloat = 0
    @State private var umbrellaFall: CGFloat = 0
    @State private var ballFall: CGFloat = 0
    @State private var zoomScale: CGFloat = 1
    @State private var zoomOverlayOpacity: CGFloat = 0
    @State private var zoomAnchor: UnitPoint = .center

    @State private var autumnForestOpacity: CGFloat = 0
    @State private var snowIntensity: CGFloat = 0
    @State private var winterSceneOpacity: CGFloat = 0
    @State private var winterSnowIntensity: CGFloat = 0
    @State private var whiteWipeProgress: CGFloat = 0
    @State private var snowCycleID = UUID()
    @State private var winterSnowEmissionIntensity: CGFloat = 0

    // States für die Fortsetzung nach der Winterszene.
    @State private var snowmanFallOffset: CGFloat = 0
    @State private var winterHillHeightFraction: CGFloat = AnimationConstants.initialWinterHillHeightFraction
    @State private var winterHillColorMix: CGFloat = 0 // 0 = weiß, 1 = grün

    // MARK: - Konstanten
    private let skyColor      = Color(red: 0.65, green: 0.85, blue: 1.00)
    private let grassColor    = Color(red: 0.62, green: 0.85, blue: 0.45)
    private let mountainColor = Color(red: 0.58, green: 0.58, blue: 0.60)
    private let waveTurquoise = Color(red: 0.30, green: 0.78, blue: 0.75)
    private let sandColor     = Color(red: 0.98, green: 0.90, blue: 0.64)
    private let umbrellaCanopyColor = Color.red
    private let umbrellaPoleColor   = Color(red: 0.30, green: 0.18, blue: 0.10)
    // Geschwindigkeit der Welle in rad/s, entspricht der alten
    // `.linear(duration: 3.5)`-Animation von 0 bis 2π.
    private let waveSpeed: CGFloat = (2 * .pi) / 3.5
    private let umbrellaRestRotation: Double = 15
    private let umbrellaXFraction: CGFloat = 0.85
    private let groundYFraction: CGFloat = 0.80
    private let ballXFraction: CGFloat = 0.28
    private let ballDiameter: CGFloat = 34
    /// Passt sich automatisch an Light/Dark Mode an (weiß bzw. schwarz) –
    /// exakt das gleiche Prinzip wie der Basis-Layer in
    /// `CookModeAnimationView` (`Color(UIColor.systemBackground)`). Wird
    /// sowohl für den allerersten Frame vor dem Intro als auch für den
    /// Wisch-Layer beim Herbst→Winter-Übergang verwendet, damit dort im
    /// Dark Mode kein greller weißer Screen mitten in der Animation
    /// aufblitzt.
    private var adaptiveBackground: Color {
        Color(UIColor.systemBackground)
    }
    private let flowers: [Flower] = (0..<20).map { _ in
        Flower(
            x:    CGFloat.random(in: 0.03...0.97),
            y:    CGFloat.random(in: 0.10...0.97),
            color: Bool.random()
                ? Color.white
                : Color(red: 1.00, green: 0.84, blue: 0.20),
            size:  20
        )
    }

    /// Mischt Weiß und die Wiesenfarbe linear anhand von `t` (0 = weiß, 1 = grün).
    private func mixedWinterHillColor(_ t: CGFloat) -> Color {
        let clamped = min(max(t, 0), 1)
        let r = 1.0 * (1 - clamped) + 0.62 * clamped
        let g = 1.0 * (1 - clamped) + 0.85 * clamped
        let b = 1.0 * (1 - clamped) + 0.45 * clamped
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            let meadowTopY = geo.size.height * 0.45
            ZStack {
                ZStack {
                    adaptiveBackground.ignoresSafeArea()
                    skyColor
                        .ignoresSafeArea()
                        .opacity(skyOpacity)
                    ZStack {
                        MountainView(
                            width: geo.size.width * 0.85,
                            height: geo.size.height * 0.36,
                            color: mountainColor
                        )
                        .position(
                            x: geo.size.width * 0.38,
                            y: meadowTopY - geo.size.height * 0.36 * 0.10
                        )
                        MountainView(
                            width: geo.size.width * 0.55,
                            height: geo.size.height * 0.22,
                            color: mountainColor
                        )
                        .position(
                            x: geo.size.width * 0.68,
                            y: meadowTopY - geo.size.height * 0.22 * 0.10
                        )
                    }
                    .offset(y: (1 - mountainsRise) * geo.size.height * 1.2)
                    ZStack {
                        HillShape()
                            .fill(grassColor)
                        ForEach(flowers) { flower in
                            Circle()
                                .fill(flower.color)
                                .frame(width: flower.size, height: flower.size)
                                .position(
                                    x: geo.size.width * flower.x,
                                    y: geo.size.height * 0.55 * flower.y
                                )
                        }
                        .opacity(flowersOpacity)
                        sandColor
                            .opacity(sandOverlayOpacity)
                    }
                    .frame(height: geo.size.height * 0.55)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .mask(
                        HillShape()
                            .frame(height: geo.size.height * 0.55)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .offset(y: (1 - hillRise) * geo.size.height * 0.55)
                    TimelineView(.animation) { timeline in
                        // Phase wird direkt aus der verstrichenen Zeit berechnet,
                        // statt über eine State-Variable mit `.repeatForever()`
                        // animiert zu werden. Dadurch läuft die Welle immer
                        // gleichmäßig weiter und es gibt beim Loop-Neustart
                        // nichts, was "abgebrochen" werden müsste – das war die
                        // Ursache für das Springen/Spinnen der Welle.
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let phase = CGFloat(time.truncatingRemainder(dividingBy: 1000)) * waveSpeed

                        MeadowWaveShape(
                            baseHeightFraction: 2.0 / 3.0,
                            amplitude: geo.size.height * 0.06,
                            frequency: 0.3,
                            phase: phase
                        )
                        .fill(waveTurquoise)
                    }
                    .ignoresSafeArea()
                    .offset(y: -(1 - waveRise) * geo.size.height)
                    Rectangle()
                        .fill(skyColor)
                        .frame(height: geo.size.height * 0.5)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)
                        .offset(y: -(1 - deepBlueRise) * geo.size.height * 0.5)
                    BeachUmbrellaView(canopyColor: umbrellaCanopyColor, poleColor: umbrellaPoleColor)
                        .position(
                            x: geo.size.width * umbrellaXFraction,
                            y: umbrellaLandingY(in: geo) - (1 - umbrellaFall) * geo.size.height
                        )
                        .rotationEffect(.degrees(umbrellaRestRotation))
                    Circle()
                        .fill(Color.white)
                        .frame(width: ballDiameter, height: ballDiameter)
                        .position(
                            x: geo.size.width * ballXFraction,
                            y: ballLandingY(in: geo) - (1 - ballFall) * geo.size.height
                        )
                }
                .overlayPreferenceValue(RedCanopyAnchorKey.self) { anchor in
                    GeometryReader { proxy -> Color in
                        if let anchor {
                            let point = proxy[anchor]
                            let resolved = UnitPoint(
                                x: point.x / proxy.size.width,
                                y: point.y / proxy.size.height
                            )
                            if zoomAnchor != resolved {
                                Task { @MainActor in
                                    zoomAnchor = resolved
                                }
                            }
                        }
                        return Color.clear
                    }
                }
                .scaleEffect(zoomScale, anchor: zoomAnchor)
                umbrellaCanopyColor
                    .ignoresSafeArea()
                    .opacity(zoomOverlayOpacity)
                    .allowsHitTesting(false)

                AutumnForestView()
                    .opacity(autumnForestOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                WinterMeadowView(
                    skyColor: skyColor,
                    hillHeightFraction: winterHillHeightFraction,
                    hillColor: mixedWinterHillColor(winterHillColorMix),
                    snowmanFallOffset: snowmanFallOffset
                )
                .opacity(winterSceneOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Bleibt auch bei Intensität 0 in der Hierarchie. Dadurch
                // kann jede neu aktivierte Flocke zuverlässig oberhalb des
                // Bildschirms erzeugt werden.
                SnowfallView(
                    intensity: max(snowIntensity, winterSnowIntensity),
                    emissionIntensity: snowIntensity > 0
                        ? snowIntensity
                        : winterSnowEmissionIntensity
                )
                    .id(snowCycleID)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Der Wisch verdeckt die Szene kurz vollständig. Genau in
                // diesem Moment wird darunter vom Herbst zum Winter gewechselt.
                Rectangle()
                    .fill(adaptiveBackground)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .position(
                        x: geo.size.width / 2,
                        y: -geo.size.height / 2 + whiteWipeProgress * geo.size.height * 2
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

            }
            .task {
                await startAnimationSequence()
            }
        }
    }

    private func umbrellaLandingY(in geo: GeometryProxy) -> CGFloat {
        geo.size.height * groundYFraction - BeachUmbrellaView.totalHeight / 2
    }
    private func ballLandingY(in geo: GeometryProxy) -> CGFloat {
        geo.size.height * groundYFraction - ballDiameter / 2
    }

    // MARK: - Animationssequenz

    /// Startet Intro + Endlos-Loop. Läuft als `.task`, wodurch die Task von
    /// SwiftUI automatisch storniert wird, sobald die View aus der
    /// Hierarchie verschwindet – dadurch läuft nach einem Verschwinden der
    /// View nichts mehr unbeobachtet im Hintergrund weiter.
    @MainActor
    private func startAnimationSequence() async {
        await playIntroOnce()
        while !Task.isCancelled {
            await runAnimationCycle()
        }
    }

    /// Setzt alle Werte zurück, die während eines Loop-Durchlaufs verändert
    /// werden. Läuft in einer Transaction mit `disablesAnimations = true`,
    /// damit jede noch laufende Animation aus dem vorherigen Durchlauf
    /// sauber abgebrochen wird, statt mit neu gestarteten Animationen zu
    /// kollidieren.
    ///
    /// - Parameter includingIntroStates: Wenn `true`, werden zusätzlich
    ///   `skyOpacity` und `hillRise` zurückgesetzt. Das wird nur einmalig
    ///   vor dem allerersten Intro benötigt – im normalen Loop bleiben
    ///   beide bewusst auf 1, da der Loop mit blauem Himmel + grüner
    ///   Fläche startet.
    private func resetLoopStartStates(includingIntroStates: Bool = false) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if includingIntroStates {
                skyOpacity = 0
                hillRise = 0
            }
            flowersOpacity = 0
            mountainsRise = 0
            waveRise = 0
            sandOverlayOpacity = 0
            deepBlueRise = 0
            umbrellaFall = 0
            ballFall = 0
            zoomScale = 1
            zoomOverlayOpacity = 0
            zoomAnchor = .center

            autumnForestOpacity = 0
            snowIntensity = 0
            winterSceneOpacity = 0
            winterSnowIntensity = 0
            whiteWipeProgress = 0
            snowCycleID = UUID()
            winterSnowEmissionIntensity = 0

            snowmanFallOffset = 0
            winterHillHeightFraction = AnimationConstants.initialWinterHillHeightFraction
            winterHillColorMix = 0
        }
    }

    /// Führt eine Liste von `SequenceStep`s der Reihe nach aus. Bricht die
    /// Sequenz sauber ab, sobald die umgebende Task storniert wurde (z. B.
    /// weil die View verschwunden ist), statt im Hintergrund unbeobachtet
    /// weiterzulaufen.
    @MainActor
    private func run(_ steps: [SequenceStep]) async {
        for step in steps {
            if Task.isCancelled { return }
            switch step {
            case .wait(let seconds):
                do {
                    try await Task.sleep(for: .seconds(seconds))
                } catch {
                    return
                }
            case .animate(let animation, let action):
                withAnimation(animation, action)
            case .instant(let action):
                action()
            case .custom(let action):
                await action()
            }
        }
    }

    /// Einmaliges Intro: Standardhintergrund → Blau, danach fährt die grüne
    /// Fläche hoch. Läuft genau ein Mal, bevor der Loop beginnt.
    private func introSteps() -> [SequenceStep] {
        [
            .instant { resetLoopStartStates(includingIntroStates: true) },
            .wait(0.4),
            .animate(.easeInOut(duration: 2.5)) { skyOpacity = 1 },
            .wait(1.8),
            .animate(.easeOut(duration: 2.2)) { hillRise = 1 },
            .wait(1.8),
        ]
    }

    @MainActor
    private func playIntroOnce() async {
        await run(introSteps())
    }

    /// Die eigentliche, endlos wiederholte Sequenz. Startet mit blauem
    /// Himmel + grüner Fläche (bereits vorhanden) und endet auch wieder
    /// genau damit. Als flaches Array aus Wartezeiten/Animationen ist die
    /// gesamte Zeitleiste auf einen Blick nachvollziehbar, statt in einer
    /// langen Kette aus `sleep`+`withAnimation`-Aufrufen verstreut zu sein.
    private func animationCycleSteps() -> [SequenceStep] {
        [
            .instant { resetLoopStartStates() },
            .wait(1.2),
            .animate(.easeIn(duration: 1.8)) { flowersOpacity = 1 },
            .wait(0.8),
            .animate(.easeOut(duration: 2.2)) { mountainsRise = 1 },
            .wait(3.0),
            .animate(.easeIn(duration: 2.0)) { mountainsRise = 0 },
            .wait(1.8),
            .animate(.easeOut(duration: 2.0)) {
                waveRise = 1
                sandOverlayOpacity = 1
            },
            .wait(2.6),
            .animate(.easeOut(duration: 2.0)) { deepBlueRise = 1 },
            .wait(1.4),
            .animate(.easeOut(duration: 1.3)) { umbrellaFall = 1 },
            .wait(1.4),
            .animate(.easeOut(duration: 1.3)) { ballFall = 1 },
            .wait(1.4),
            .animate(.easeIn(duration: 2.8)) {
                zoomScale = AnimationConstants.umbrellaZoomTargetScale
            },
            .wait(2.0),
            .animate(.easeIn(duration: 0.6)) { zoomOverlayOpacity = 1 },

            .wait(1.2),
            .animate(.easeInOut(duration: 3.2)) { autumnForestOpacity = 1 },
            .wait(2.0),
            .custom { await self.increaseSnowfallSmoothly(duration: 15.0) },

            // Bei voller Dichte bleibt der Sturm noch länger sichtbar im
            // Bild, damit sich vor dem Szenenwechsel deutlich mehr weiße
            // Punkte sammeln – ähnlich den großzügigen Standzeiten in
            // CookModeAnimationView (z. B. 8s sichtbare Bubbles).
            .wait(5.0),

            // Phase 1: Die weiße/schwarze Fläche fährt bis zur
            // Bildschirmmitte. Dort bedeckt sie den gesamten Bildschirm
            // vollständig.
            .animate(.linear(duration: 2.8)) { whiteWipeProgress = 0.5 },
            .wait(2.8),

            // Während die Fläche den Bildschirm verdeckt, wird die Szene
            // darunter ausgewechselt. Sie bleibt anschließend bewusst einen
            // Moment stehen.
            .instant {
                autumnForestOpacity = 0
                snowIntensity = 0
                zoomOverlayOpacity = 0
                winterSceneOpacity = 1
                winterSnowIntensity = 1
                winterSnowEmissionIntensity = 1
            },
            .wait(1.8),

            // Phase 2: Die Fläche fährt weiter nach unten und gibt die
            // bereits vorbereitete Winter-Szene wieder frei.
            .animate(.linear(duration: 2.8)) { whiteWipeProgress = 1 },
            .wait(2.8),

            // Der Rücklauf ist das Gegenstück zum Aufbau: Die Emission wird
            // in kleinen Schritten reduziert. Immer weniger Flocken
            // beginnen einen neuen Fall, während die bereits sichtbaren
            // normal unten ankommen.
            .custom { await self.decreaseWinterSnowEmissionSmoothly(duration: 7.0) },
            .wait(6.5),
            .instant { winterSnowIntensity = 0 },

            // Der Schneemann sinkt nach unten und verschwindet dabei hinter
            // der weißen Fläche (Zeichenreihenfolge in WinterMeadowView
            // sorgt für die Verdeckung).
            .wait(6.5),
            .animate(.easeIn(duration: 2.2)) {
                snowmanFallOffset = AnimationConstants.snowmanSinkDistance
            },

            // Die weiße Fläche wächst auf die Höhe der grünen Anfangsfläche.
            .wait(2.2),
            .animate(.easeInOut(duration: 2.4)) {
                winterHillHeightFraction = AnimationConstants.summerHillHeightFraction
            },

            // Die weiße Fläche wird grün.
            .wait(2.4),
            .animate(.easeInOut(duration: 2.4)) { winterHillColorMix = 1 },

            // Kurze Pause – der Bildschirm zeigt jetzt wieder blauen Himmel
            // und eine grüne Fläche. An dieser Stelle beginnt der Loop
            // erneut, ohne erneute Hintergrund-/Hügel-Einblendung.
            .wait(2.8),
        ]
    }

    @MainActor
    private func runAnimationCycle() async {
        await run(animationCycleSteps())
    }

    /// Erhöht die Dichte in kleinen Zeitabständen. Anders als bei einer
    /// einzelnen Zielanimation erhält SnowfallView so fortlaufend neue Werte
    /// und kann jede zusätzliche Flocke oberhalb des Bildschirms starten.
    @MainActor
    private func increaseSnowfallSmoothly(duration: Double) async {
        let steps = max(1, Int(duration * 10))
        for step in 1...steps {
            do {
                try await Task.sleep(for: .seconds(duration / Double(steps)))
            } catch {
                return
            }
            let progress = CGFloat(step) / CGFloat(steps)
            // Smoothstep: sanfter Start und sanftes Verdichten zum Schluss.
            snowIntensity = progress * progress * (3 - 2 * progress)
        }
    }

    /// Spiegelbild zum Aufbau: reduziert nach und nach die Anzahl der
    /// Flocken, die noch einen weiteren Fall beginnen dürfen.
    @MainActor
    private func decreaseWinterSnowEmissionSmoothly(duration: Double) async {
        let steps = max(1, Int(duration * 10))
        for step in 1...steps {
            do {
                try await Task.sleep(for: .seconds(duration / Double(steps)))
            } catch {
                return
            }
            let progress = CGFloat(step) / CGFloat(steps)
            let smoothProgress = progress * progress * (3 - 2 * progress)
            winterSnowEmissionIntensity = 1 - smoothProgress
        }
    }

}

// MARK: - Winterwiese
private struct WinterMeadowView: View {
    let skyColor: Color
    let hillHeightFraction: CGFloat
    let hillColor: Color
    let snowmanFallOffset: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                skyColor

                // Der Schneemann wird zuerst gezeichnet, damit die danach
                // gezeichnete (und wachsende) Fläche ihn beim Sinken
                // verdecken kann.
                SnowmanView(baseDiameter: min(geo.size.width * 0.32, 130))
                    .position(
                        x: geo.size.width * 0.50,
                        y: geo.size.height * 0.52 + snowmanFallOffset
                    )

                HillShape()
                    .fill(hillColor)
                    .frame(height: geo.size.height * hillHeightFraction)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// MARK: - Schneemann
private struct SnowmanView: View {
    let baseDiameter: CGFloat

    private var middleDiameter: CGFloat { baseDiameter * 0.76 }
    private var headDiameter: CGFloat { baseDiameter * 0.58 }

    var body: some View {
        ZStack {
            // Die äußeren Enden der Arme zeigen nach oben (Stärke: 4)
            Capsule()
                .fill(Color(red: 0.34, green: 0.20, blue: 0.09))
                .frame(width: baseDiameter * 0.78, height: 4)
                .rotationEffect(.degrees(18))
                .position(x: baseDiameter * 0.38, y: baseDiameter * 1.37)
            Capsule()
                .fill(Color(red: 0.34, green: 0.20, blue: 0.09))
                .frame(width: baseDiameter * 0.78, height: 4)
                .rotationEffect(.degrees(-18))
                .position(x: baseDiameter * 1.62, y: baseDiameter * 1.37)

            snowball(diameter: baseDiameter)
                .position(x: baseDiameter, y: baseDiameter * 2.15)
            snowball(diameter: middleDiameter)
                .position(x: baseDiameter, y: baseDiameter * 1.38)
            // Kopf etwas weiter nach unten verschoben (0.72 -> 0.80),
            // damit er die mittlere Kugel sichtbar überlappt.
            snowball(diameter: headDiameter)
                .position(x: baseDiameter, y: baseDiameter * 0.80)

            // Augen auf der oberen Kugel (gleichermaßen minimal höher gesetzt)
            Circle().fill(.black)
                .frame(width: 7, height: 7)
                .position(x: baseDiameter * 0.90, y: baseDiameter * 0.715)
            Circle().fill(.black)
                .frame(width: 7, height: 7)
                .position(x: baseDiameter * 1.10, y: baseDiameter * 0.715)
            
            // Orangener Punkt (Nase) gleichermaßen minimal höher gesetzt
            Circle().fill(.orange)
                .frame(width: 9, height: 9)
                .position(x: baseDiameter, y: baseDiameter * 0.82)

            // Lächelnder Mund in etwas hellerem Grau, gleichermaßen minimal höher gesetzt
            SmileShape()
                .stroke(Color.gray.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: baseDiameter * 0.26, height: baseDiameter * 0.11)
                .position(x: baseDiameter, y: baseDiameter * 0.975)

            // Drei Knöpfe auf der mittleren Kugel.
            ForEach([0.0, 1.0, 2.0], id: \.self) { index in
                Circle()
                    .fill(.black)
                    .frame(width: 7, height: 7)
                    .position(x: baseDiameter, y: baseDiameter * (1.18 + index * 0.20))
            }
        }
        .frame(width: baseDiameter * 2, height: baseDiameter * 2.8)
    }

    private func snowball(diameter: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.blue.opacity(0.16), lineWidth: 1))
            .frame(width: diameter, height: diameter)
    }
}

/// Einfache Lächeln-Kurve als leicht nach unten gewölbter Bogen.
private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

// MARK: - Herbstwald
private struct AutumnForestView: View {
    @State private var leaves: [Leaf] = []
    @State private var trees: [Tree] = []

    private let treeCount = 7 // Mehr Stämme für einen dichteren Look

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1) Baumstämme mit individueller Länge und Position
                ForEach(trees) { tree in
                    Rectangle()
                        .fill(Color(red: 0.35, green: 0.22, blue: 0.10)) // braun
                        .frame(width: tree.width, height: geo.size.height * tree.heightFraction)
                        .position(
                            x: geo.size.width * tree.xFraction,
                            y: geo.size.height * tree.yCenterFraction
                        )
                }
               
                // 2) Blätter (Punkte)
                ForEach(leaves) { leaf in
                    Circle()
                        .fill(leaf.color)
                        .frame(width: leaf.size, height: leaf.size)
                        .position(
                            x: geo.size.width * leaf.xFraction,
                            y: geo.size.height * leaf.yFraction
                        )
                }
            }
            .onAppear {
                guard leaves.isEmpty, trees.isEmpty else { return }
                generateForest()
            }
        }
    }

    /// Würfelt Bäume und Blätter neu aus. Da diese View bei jedem
    /// Loop-Durchlauf neu erzeugt wird (`autumnForestOpacity` blendet sie
    /// ein/aus, die View selbst bleibt aber Teil des Baums – `onAppear`
    /// feuert dennoch nur beim allerersten Erscheinen, da `leaves`/`trees`
    /// danach nicht mehr leer sind), ist der generierte Wald über die
    /// gesamte Lebensdauer der View hinweg stabil und wechselt nicht bei
    /// jedem Loop-Durchgang. Das ist bewusst so gewählt, damit der Herbst
    /// nicht bei jedem Zyklus optisch "springt".
    private func generateForest() {
        var generatedTrees: [Tree] = []
        for i in 0..<treeCount {
            let slot = (CGFloat(i) + 0.5) / CGFloat(treeCount)
            let jitterX = CGFloat.random(in: -0.04...0.04)
            let xFrac = min(max(slot + jitterX, 0.03), 0.97)
             
            // Jeder Stamm bekommt eine individuellere Höhe und Position
            let heightFrac = CGFloat.random(in: 0.45...0.85) // variiert zwischen 45% und 85% Bildschirmhöhe
            let yCenterFrac = CGFloat.random(in: 0.30...0.55) // verschiebt den Mittelpunkt nach oben/unten
            let width = CGFloat.random(in: 10...18)            // variierende Stammdicke
            let overlayChance = Double.random(in: 0.20...0.65) // unterschiedlich stark verdeckt (weniger = mehr Punkte sichtbar)
             
            generatedTrees.append(Tree(
                xFraction: xFrac,
                heightFraction: heightFrac,
                yCenterFraction: yCenterFrac,
                width: width,
                overlayThreshold: overlayChance
            ))
        }
        trees = generatedTrees

        let columns = 22
        let rows = 42
        var generatedLeaves: [Leaf] = []
        generatedLeaves.reserveCapacity(columns * rows)
         
        let darkGreen = Color(red: 0.1, green: 0.4, blue: 0.1)
         
        for col in 0..<columns {
            for row in 0..<rows {
                let baseX = (CGFloat(col) + 0.5) / CGFloat(columns)
                let baseY = (CGFloat(row) + 0.5) / CGFloat(rows)
                let jitterX = CGFloat.random(in: -0.9...0.9) / CGFloat(columns) / 2
                let jitterY = CGFloat.random(in: -0.9...0.9) / CGFloat(rows) / 2
                 
                let finalX = min(max(baseX + jitterX, 0), 1)
                let finalY = min(max(baseY + jitterY, 0), 1)
                 
                // Prüfen, ob das Blatt horizontal im Bereich eines individuellen Baumstamms liegt
                let matchingTree = generatedTrees.first { tree in
                    abs(tree.xFraction - finalX) < 0.035
                }
                 
                if let tree = matchingTree {
                    // Berechnen, ob das Blatt vertikal genau im Bereich dieses spezifischen Stammes liegt
                    let treeTop = tree.yCenterFraction - (tree.heightFraction / 2.0)
                    let treeBottom = tree.yCenterFraction + (tree.heightFraction / 2.0)
                     
                    if finalY >= treeTop && finalY <= treeBottom {
                        // Nutzt den individuellen Verdeckungs-Faktor des jeweiligen Baumes
                        if Double.random(in: 0...1) < tree.overlayThreshold {
                            continue
                        }
                    }
                }
                 
                // Fuzzy Boundary: Sanfterer Übergang der Farben durch Zufallsversatz bei der Farbauswahl
                let colorBlurY = finalY + CGFloat.random(in: -0.15...0.15)
                 
                let leafColor: Color
                let randomValue = Double.random(in: 0...1)
                 
                if colorBlurY > 0.66 {
                    // Unteres Bildschirmdrittel – unverändert
                    if randomValue < 0.33 {
                        leafColor = .orange
                    } else if randomValue < 0.66 {
                        leafColor = .yellow
                    } else {
                        leafColor = .red
                    }
                } else if colorBlurY > 0.44 {
                    // Unterer Bereich der oberen 2/3: vor allem Grün und Gelb
                    if randomValue < 0.45 {
                        leafColor = darkGreen
                    } else if randomValue < 0.90 {
                        leafColor = .yellow
                    } else if randomValue < 0.95 {
                        leafColor = .orange
                    } else {
                        leafColor = .red
                    }
                } else if colorBlurY > 0.22 {
                    // Mittlerer Bereich der oberen 2/3: vor allem Gelb und Orange
                    if randomValue < 0.45 {
                        leafColor = .yellow
                    } else if randomValue < 0.90 {
                        leafColor = .orange
                    } else if randomValue < 0.95 {
                        leafColor = darkGreen
                    } else {
                        leafColor = .red
                    }
                } else {
                    // Oberer Bereich: vor allem Rot und Orange
                    if randomValue < 0.45 {
                        leafColor = .red
                    } else if randomValue < 0.90 {
                        leafColor = .orange
                    } else if randomValue < 0.95 {
                        leafColor = .yellow
                    } else {
                        leafColor = darkGreen
                    }
                }
                 
                generatedLeaves.append(
                    Leaf(
                        xFraction: finalX,
                        yFraction: finalY,
                        size: CGFloat.random(in: 16...28),
                        color: leafColor
                    )
                )
            }
        }
        leaves = generatedLeaves
    }

    struct Tree: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let heightFraction: CGFloat
        let yCenterFraction: CGFloat
        let width: CGFloat
        let overlayThreshold: Double
    }

    struct Leaf: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let yFraction: CGFloat
        let size: CGFloat
        let color: Color
    }
}

// MARK: - Schneefall (Canvas-basiert, mit natürlichem Start und Ablagerung)
private struct SnowfallView: View {
    /// Steuert, wie viele Flocken insgesamt existieren (0 ... 1, relativ zur
    /// maximal möglichen Dichte). Eine Erhöhung fügt neue Flocken hinzu, die
    /// oberhalb des Bildschirms starten (siehe `scheduleNewFlakes`).
    let intensity: CGFloat
    /// Steuert unabhängig von `intensity`, wie viele bereits existierende
    /// Flocken nach ihrem aktuellen Fall noch einen weiteren Zyklus beginnen
    /// dürfen. Wird sie reduziert, beenden betroffene Flocken nur noch ihren
    /// laufenden Fall und werden danach nicht neu gestartet – dadurch endet
    /// der Schneefall sanft auslaufend statt abrupt abzubrechen (siehe
    /// `retireFlakesIfNeeded`).
    let emissionIntensity: CGFloat

    // Die Herbstpunkte sind 16 ... 28 pt groß; 22 pt ist ihre mittlere Größe.
    // Die Dichte ist hoch genug für starken Schneefall; die vollständige
    // Überdeckung am Szenenwechsel übernimmt danach bewusst der weiße Wisch.
    private let flakeDiameter: CGFloat = 22
    /// Obergrenze für die Flockenzahl. Ohne Geräteunterscheidung würde die
    /// Dichteformel in `targetFlakeCount` auf einem iPhone bereits nahe an
    /// dieser Grenze gekappt (bei ~390×844 pt liegt sie schon bei ~2.720),
    /// auf einem deutlich größeren iPad-Bildschirm aber genauso stark
    /// gekappt werden – dieselbe Flockenzahl verteilt sich dann auf eine
    /// viel größere Fläche, der Schnee wirkt dort spürbar dünner. Ein
    /// höherer Cap für `.pad` hält die Flocken-*Dichte* pro Fläche
    /// zwischen den Gerätetypen ungefähr konstant. Das Prinzip entspricht
    /// dem Geräte-Check in `CookModeAnimationView`
    /// (`UIDevice.current.userInterfaceIdiom == .pad`). Dank der
    /// gebündelten Canvas-Fills (siehe `opacityBuckets`) bleibt das auch
    /// bei deutlich mehr Flocken performant genug.
    private var maximumFlakeCount: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 8_000 : 2_800
    }
    /// Anzahl der Deckkraft-Stufen, in die Flocken beim Zeichnen gruppiert
    /// werden. Statt eines `context.fill()` pro Flocke (bei bis zu 2600
    /// Flocken potenziell mehrere tausend Draw-Calls pro Frame) werden alle
    /// Flocken mit ähnlicher Deckkraft in einem gemeinsamen `Path`
    /// gesammelt und mit einem einzigen Fill pro Bucket gezeichnet. Das
    /// reduziert die Draw-Calls auf höchstens `opacityBuckets * 2` pro
    /// Frame und entlastet die Rendering-Performance spürbar.
    private let opacityBuckets = 12

    @State private var flakes: [Snowflake] = []
    @State private var scheduledCount = 0
    @State private var canvasSize: CGSize = .zero
    @State private var retirementTimes: [UUID: TimeInterval] = [:]
    @State private var previousEmissionIntensity: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let activeCount = targetFlakeCount(for: size)

                    var flightPaths = [Int: Path]()
                    var groundPaths = [Int: Path]()

                    for flake in flakes.prefix(activeCount) {
                        let age = now - flake.launchTime
                        guard age >= 0 else { continue }

                        // Eine im Rücklauf stillgelegte Flocke beendet nur
                        // noch ihren gerade laufenden Fall. Sie taucht danach
                        // nicht wieder oben auf und verschwindet nie abrupt.
                        if let retirementTime = retirementTimes[flake.id] {
                            let ageAtRetirement = retirementTime - flake.launchTime
                            guard ageAtRetirement >= 0 else { continue }
                            let currentCycle = floor(ageAtRetirement / flake.fallDuration)
                            let finalLandingTime = flake.launchTime
                                + (currentCycle + 1) * flake.fallDuration
                            guard now < finalLandingTime else { continue }
                        }

                        let cycleProgress = (age
                            .truncatingRemainder(dividingBy: flake.fallDuration))
                            / flake.fallDuration
                        let y = -flakeDiameter
                            + CGFloat(cycleProgress) * (size.height + flakeDiameter * 2)
                        let x = size.width * flake.xFraction
                            + sin(CGFloat(now) * flake.swaySpeed + flake.swayPhase)
                            * flake.swayAmplitude

                        let flightRect = CGRect(
                            x: x - flakeDiameter / 2,
                            y: y - flakeDiameter / 2,
                            width: flakeDiameter,
                            height: flakeDiameter
                        )
                        // Sanfter Start: Keine Flocke ploppt plötzlich auf.
                        let arrivalOpacity = min(1, CGFloat(age / 0.28))
                        let flightBucket = Int((arrivalOpacity * CGFloat(opacityBuckets)).rounded())
                        if flightBucket > 0 {
                            flightPaths[flightBucket, default: Path()].addEllipse(in: flightRect)
                        }

                        // Nach dem ersten Landen bleibt eine gleich große Flocke
                        // im unteren Drittel liegen. So wächst die Schneedecke.
                        let settledAge = age - flake.fallDuration
                        guard settledAge >= 0 else { continue }
                        let settlingOpacity = min(1, CGFloat(settledAge / 1.2))
                        let groundRect = CGRect(
                            x: size.width * flake.groundXFraction - flakeDiameter / 2,
                            y: size.height * (0.67 + flake.groundYFraction * 0.33)
                                - flakeDiameter / 2,
                            width: flakeDiameter,
                            height: flakeDiameter
                        )
                        let groundBucket = Int((settlingOpacity * CGFloat(opacityBuckets)).rounded())
                        if groundBucket > 0 {
                            groundPaths[groundBucket, default: Path()].addEllipse(in: groundRect)
                        }
                    }

                    // Erst die liegen gebliebene Schneedecke zeichnen, danach
                    // die fliegenden Flocken darüber – so verschwinden
                    // fallende Flocken nicht unter der bereits liegenden
                    // Decke.
                    for (bucket, path) in groundPaths {
                        let opacity = CGFloat(bucket) / CGFloat(opacityBuckets)
                        context.fill(path, with: .color(.white.opacity(opacity)))
                    }
                    for (bucket, path) in flightPaths {
                        let opacity = CGFloat(bucket) / CGFloat(opacityBuckets)
                        context.fill(path, with: .color(.white.opacity(opacity)))
                    }
                }
            }
            .onAppear {
                canvasSize = geo.size
                scheduleNewFlakes()
            }
            .onChange(of: geo.size) { newSize in
                canvasSize = newSize
                scheduleNewFlakes()
            }
            .onChange(of: intensity) { _ in
                scheduleNewFlakes()
            }
            .onChange(of: emissionIntensity) { newIntensity in
                retireFlakesIfNeeded(for: newIntensity)
            }
        }
        .allowsHitTesting(false)
    }

    /// Fügt nur Flocken hinzu, die mit der neuen Dichte benötigt werden.
    /// Der individuelle Startversatz sorgt dafür, dass sie oben einfliegen.
    private func scheduleNewFlakes() {
        guard canvasSize != .zero else { return }
        let desiredCount = targetFlakeCount(for: canvasSize)
        guard desiredCount > scheduledCount else { return }

        let now = Date().timeIntervalSinceReferenceDate
        let additions = (scheduledCount..<desiredCount).map { _ in
            Snowflake(
                xFraction: CGFloat.random(in: 0...1),
                groundXFraction: CGFloat.random(in: 0...1),
                groundYFraction: CGFloat.random(in: 0...1),
                retirementThreshold: CGFloat.random(in: 0...1),
                launchTime: now + Double.random(in: 0...1.6),
                fallDuration: Double.random(in: 3.2...5.7),
                swayAmplitude: CGFloat.random(in: 3...11),
                swaySpeed: CGFloat.random(in: 0.55...1.1),
                swayPhase: CGFloat.random(in: 0...(2 * .pi))
            )
        }
        flakes.append(contentsOf: additions)
        scheduledCount = desiredCount
    }

    /// Bei sinkender Emission werden nur einige Flocken pro Schritt in den
    /// Ruhestand versetzt. Das erzeugt den gleichen allmählichen Eindruck wie
    /// beim vorherigen Hinzufügen neuer Flocken – nur in umgekehrter Richtung.
    private func retireFlakesIfNeeded(for newIntensity: CGFloat) {
        defer { previousEmissionIntensity = newIntensity }
        guard newIntensity < previousEmissionIntensity else { return }

        let now = Date().timeIntervalSinceReferenceDate
        for flake in flakes where flake.retirementThreshold > newIntensity {
            guard retirementTimes[flake.id] == nil else { continue }
            retirementTimes[flake.id] = now
        }
    }

    private func targetFlakeCount(for size: CGSize) -> Int {
        let density = min(max(intensity, 0), 1)
        // Genug Flocken für einen dichten Schneesturm, aber nicht so viele,
        // dass sie die spätere weiße Wischfläche vorwegnehmen.
        let fullCoverageCount = min(
            maximumFlakeCount,
            Int((size.width * size.height) / (flakeDiameter * flakeDiameter) * 4)
        )
        return Int((CGFloat(fullCoverageCount) * density).rounded())
    }

    private struct Snowflake: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let groundXFraction: CGFloat
        let groundYFraction: CGFloat
        let retirementThreshold: CGFloat
        let launchTime: TimeInterval
        let fallDuration: TimeInterval
        let swayAmplitude: CGFloat
        let swaySpeed: CGFloat
        let swayPhase: CGFloat
    }
}

// MARK: - Restliche existierende Strukturen
private struct Flower: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let size: CGFloat
}

struct HillShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.10))
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.10),
            control: CGPoint(x: w * 0.5, y: h * 0.02)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct MountainView: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    private var capWidth: CGFloat { width * 0.34 }
    private var capHeight: CGFloat { height * 0.30 }
    var body: some View {
        ZStack(alignment: .top) {
            MountainShape()
                .fill(color)
            MountainShape()
                .fill(Color.white)
                .frame(width: capWidth, height: capHeight)
        }
        .frame(width: width, height: height)
    }
}

struct MeadowWaveShape: Shape {
    var baseHeightFraction: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let width  = rect.width
        let baseY  = rect.height * baseHeightFraction
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: baseY))
        let step = max(width / 180, 1)
        var x: CGFloat = 0
        while x <= width {
            let relativeX = x / width
            let y = baseY + amplitude * sin(relativeX * frequency * 2 * .pi + phase)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: width, y: baseY + amplitude * sin(frequency * 2 * .pi + phase)))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}

private struct CanopyWedge: Shape {
    let startAngleDeg: Double
    let endAngleDeg: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radiusX = rect.width / 2
        let radiusY = rect.height
        var path = Path()
        path.move(to: center)
        let steps = 16
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = startAngleDeg + (endAngleDeg - startAngleDeg) * t
            let rad = angle * .pi / 180
            let x = center.x + radiusX * CGFloat(cos(rad))
            let y = center.y - radiusY * CGFloat(sin(rad))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}

private struct BeachUmbrellaView: View {
    let canopyColor: Color
    let poleColor: Color
    static let canopyWidth: CGFloat  = 150
    static let canopyHeight: CGFloat = 52
    static let poleHeight: CGFloat   = 95
    static let totalHeight: CGFloat  = canopyHeight + poleHeight
    private let stripeCount = 7
    private var redMarkerPoint: CGPoint {
        let radiusX = Self.canopyWidth / 2
        let radiusY = Self.canopyHeight
        let redSegmentIndex = 1
        let step = 180.0 / Double(stripeCount)
        let angleDeg = (Double(redSegmentIndex) + 0.5) * step
        let r: CGFloat = 0.6
        let rad = angleDeg * Double.pi / 180
        let x = radiusX + r * radiusX * CGFloat(cos(rad))
        let y = radiusY - r * radiusY * CGFloat(sin(rad))
        return CGPoint(x: x, y: y)
    }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<stripeCount, id: \.self) { i in
                    let step = 180.0 / Double(stripeCount)
                    CanopyWedge(
                        startAngleDeg: Double(i) * step,
                        endAngleDeg: Double(i + 1) * step
                    )
                    .fill(i % 2 == 0 ? Color.white : canopyColor)
                }
                CanopyWedge(startAngleDeg: 0, endAngleDeg: 180)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
                Color.clear
                    .frame(width: 1, height: 1)
                    .position(redMarkerPoint)
                    .anchorPreference(key: RedCanopyAnchorKey.self, value: .center) { $0 }
            }
            .frame(width: Self.canopyWidth, height: Self.canopyHeight)
            Rectangle()
                .fill(poleColor)
                .frame(width: 4, height: Self.poleHeight)
        }
    }
}

#Preview {
    MeadowView()
}
