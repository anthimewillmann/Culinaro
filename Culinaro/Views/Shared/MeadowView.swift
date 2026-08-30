import SwiftUI
// MARK: - Architekturänderung: zeitbasierte statt zustandsbasierte Animation
//
// FRÜHER: Die komplette Animation lief als imperative Sequenz aus
// `@State`-Variablen, die per `Task.sleep` + `withAnimation` nacheinander
// gesetzt wurden (`startAnimationSequence()` in einem `.task`).
//
// PROBLEM: Sobald `MeadowView` direkt in einzelnen Tab-Screens eingebettet
// wurde (statt in einem einzigen, dauerhaften Hintergrundfenster), zeigte
// sich, dass `TabView` die View eines gerade nicht sichtbaren Tabs
// offenbar entladen und bei Rückkehr neu erzeugen kann — auch ganz ohne
// eigenes `.id()`-Reset. Jede neu erzeugte Instanz startete ihre
// `@State`-Sequenz wieder bei Null, was zu doppeltem/unvollständigem
// Overlap führte (z. B. Strand- und Winterszene gleichzeitig sichtbar).
//
// LÖSUNG: Der komplette Render-Zustand wird jetzt bei JEDEM Frame als
// reine Funktion der seit einem geteilten, für die gesamte App-Laufzeit
// festen Startzeitpunkt (`sharedAnimationStartDate`, ein `static let` —
// wird beim allerersten Zugriff einmalig gesetzt und danach von JEDER
// Instanz von `MeadowView` geteilt) verstrichenen Zeit neu berechnet
// (`renderState(at:)`). Dadurch zeigen zwei MeadowView-Instanzen zur
// exakt gleichen Uhrzeit immer exakt denselben Frame — komplett
// unabhängig davon, wann die jeweilige Instanz selbst erzeugt wurde. Eine
// neu erzeugte Instanz "springt" nicht mehr an den Anfang, sondern direkt
// an die korrekte Stelle im Ablauf.
//
// Einzige bewusste Einschränkung: `SnowfallView` verwaltet ihre einzelnen
// Flocken weiterhin in eigenem `@State` (Performance-Gründe, siehe dort).
// Wird eine `MeadowView`-Instanz mitten in einer aktiven Schneephase neu
// erzeugt, poppen ihre Flocken beim Neustart etwas abrupter ein, statt
// gestaffelt von oben hereinzufliegen — ein kleiner kosmetischer
// Kompromiss, kein funktionaler Rücksprung mehr.
/// Benannte Konstanten für Kernparameter der Animation.
private enum AnimationConstants {
    /// Mindest-Zielzoom für kleinere Displays.
    static let umbrellaZoomTargetScale: CGFloat = 45
    /// Auf größeren Displays wächst der Ziel-Zoom proportional zur Breite.
    /// Der Wert 8 stellt sicher, dass das rote Mittelsegment auch auf dem iPad
    /// über alle Bildschirmränder hinaus vergrößert wird.
    static let umbrellaZoomWidthDivisor: CGFloat = 8
    /// Strecke, um die der Schneemann am Ende der Winterszene nach unten sinkt.
    static let snowmanSinkDistance: CGFloat = 260
    /// Hügelhöhe der Winterszene direkt nach dem weißen Wisch (vor dem Wachsen).
    static let initialWinterHillHeightFraction: CGFloat = 0.36
    /// Zielhöhe des Wintergrund-Hügels: identisch zur grünen Anfangsfläche.
    static let summerHillHeightFraction: CGFloat = 0.55
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
///
/// Der gesamte Ablauf ist als reine Funktion der verstrichenen Zeit
/// implementiert (siehe `renderState(at:)`) — siehe Architekturkommentar
/// am Dateianfang.
struct MeadowView: View {
    // MARK: - Environment
    @Environment(\.colorScheme) private var colorScheme
    /// Reference date shared by the app-level background manager. Updating it
    /// restarts the animation for every visible `MeadowView` instance.
    let animationStartDate: Date
    init(animationStartDate: Date = Date()) {
        self.animationStartDate = animationStartDate
    }
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
    /// Passt sich an Light/Dark Mode an (weiß bzw. schwarz) – gleiches
    /// Prinzip wie der Readability-Overlay in `CookModeView`. Wird nur für
    /// den allerersten Frame vor dem Intro verwendet, bevor der Himmel
    /// einblendet.
    private var adaptiveBackground: Color {
        colorScheme == .dark ? .black : .white
    }
    private static let sharedFlowers: [Flower] = (0..<20).map { _ in
        Flower(
            x:    CGFloat.random(in: 0.03...0.97),
            y:    CGFloat.random(in: 0.10...0.97),
            color: Bool.random()
                ? Color.white
                : Color(red: 1.00, green: 0.84, blue: 0.20),
            size:  20
        )
    }
    private let flowers = Self.sharedFlowers
    /// Mischt Weiß und die Wiesenfarbe linear anhand von `t` (0 = weiß, 1 = grün).
    private func mixedWinterHillColor(_ t: CGFloat) -> Color {
        let clamped = min(max(t, 0), 1)
        let r = 1.0 * (1 - clamped) + 0.62 * clamped
        let g = 1.0 * (1 - clamped) + 0.85 * clamped
        let b = 1.0 * (1 - clamped) + 0.45 * clamped
        return Color(red: r, green: g, blue: b)
    }
    // MARK: - Zeitleiste
    //
    // Alle Zeitangaben in Sekunden, exakt aus der ursprünglichen
    // `SequenceStep`-Kette übernommen (kumulative Summe aus `.wait(...)` +
    // `.animate(duration:)`-Werten), nur jetzt als benannte, statische
    // Zeitpunkte statt als sequenziell abgearbeitete Schritte.
    private enum Timing {
        static let introSkyStart = 0.4
        static let introSkyDuration = 2.5
        static let introHillStart = 4.7
        static let introHillDuration = 2.2
        static let introTotalDuration = 8.7
        static let flowersStart = 1.2
        static let flowersDuration = 1.8
        static let mountainsRiseStart = 3.8
        static let mountainsRiseDuration = 2.2
        static let mountainsFallStart = 9.0
        static let mountainsFallDuration = 2.0
        static let waveStart = 12.8
        static let waveDuration = 2.0
        static let deepBlueStart = 17.4
        static let deepBlueDuration = 2.0
        static let umbrellaStart = 20.8
        static let umbrellaDuration = 1.3
        static let ballStart = 23.5
        static let ballDuration = 1.3
        static let zoomStart = 26.2
        static let zoomDuration = 2.8
        static let zoomEnd = zoomStart + zoomDuration
        static let autumnStart = 32.8
        static let autumnDuration = 3.2
        static let snowIncreaseStart = 38.0
        static let snowIncreaseDuration = 15.0
        static let whiteWipe1Start = 58.0
        static let whiteWipe1Duration = 2.8
        /// Harter Szenenwechsel Herbst → Winter, während der weiße Wisch
        /// den Bildschirm komplett verdeckt (entspricht dem ehemaligen
        /// `.instant { ... }`-Block).
        static let sceneSwitchTime = 63.6
        static let whiteWipe2Start = 65.4
        static let whiteWipe2Duration = 2.8
        static let snowDecreaseStart = 71.0
        static let snowDecreaseDuration = 7.0
        static let winterSnowOffTime = 84.5
        static let snowmanFallStart = 91.0
        static let snowmanFallDuration = 2.2
        static let hillGrowStart = 95.4
        static let hillGrowDuration = 2.4
        static let hillColorStart = 100.2
        static let hillColorDuration = 2.4
        /// Gesamtlänge eines Loop-Durchlaufs (ohne Intro).
        static let cycleDuration = 105.4
    }
    private enum Easing {
        case linear, easeIn, easeOut, easeInOut
    }
    /// Berechnet den geklemmten, geglätteten Fortschritt (0...1) für einen
    /// Zeitpunkt `t` innerhalb eines Fensters `[start, start + duration]`.
    /// Ersetzt SwiftUIs `withAnimation`-Kurven durch direkt berechnete
    /// Näherungen — visuell sehr nah an den Originalen, aber als reine,
    /// synchrone Funktion statt einer laufenden Animation.
    ///
    /// `easeIn`/`easeOut` nutzen Sinus-basierte statt quadratische Kurven:
    /// Die quadratische Variante (`p²` bzw. `1-(1-p)²`) kommt bei `easeOut`
    /// exakt bei Fortschritt 1 abrupt auf Geschwindigkeit 0 — bei größeren,
    /// bildschirmfüllenden Bewegungen (z. B. die herunterkommende Welle)
    /// wirkte dieses harte Abbremsen wie ein kurzes "Hakeln" statt eines
    /// weichen Ausklingens. Die Sinus-Variante bremst gleichmäßiger ab.
    private func progress(_ t: Double, start: Double, duration: Double, _ curve: Easing) -> Double {
        guard duration > 0 else { return t >= start ? 1 : 0 }
        let raw = (t - start) / duration
        let clamped = min(max(raw, 0), 1)
        switch curve {
        case .linear:
            return clamped
        case .easeIn:
            return 1 - cos(clamped * .pi / 2)
        case .easeOut:
            return sin(clamped * .pi / 2)
        case .easeInOut:
            return clamped * clamped * (3 - 2 * clamped)
        }
    }
    /// Alle für einen Frame benötigten Render-Werte. Wird bei jedem Tick
    /// von `TimelineView` frisch aus `renderState(at:)` berechnet.
    private struct RenderState {
        var skyOpacity: CGFloat = 0
        var hillRise: CGFloat = 0
        var flowersOpacity: CGFloat = 0
        var mountainsRise: CGFloat = 0
        var waveRise: CGFloat = 0
        /// Einmaliger Schaltwert pro Loop. Nur dieser Bool löst die native
        /// SwiftUI-Animation der türkisen Ebene aus.
        var waveActive: Bool = false
        /// Kontinuierliche, von der Abwärtsbewegung unabhängige Wellenphase.
        var wavePhase: CGFloat = 0
        var sandOverlayOpacity: CGFloat = 0
        var deepBlueRise: CGFloat = 0
        var umbrellaFall: CGFloat = 0
        var ballFall: CGFloat = 0
        /// Durchgehend beschleunigter Zoomfortschritt von 0 bis 1.
        var zoomProgress: CGFloat = 0
        var zoomOverlayOpacity: CGFloat = 0
        var autumnForestOpacity: CGFloat = 0
        var snowIntensity: CGFloat = 0
        var winterSceneOpacity: CGFloat = 0
        var winterSnowIntensity: CGFloat = 0
        var winterSnowEmissionIntensity: CGFloat = 0
        var cycleStartReferenceTime: TimeInterval = 0
        var whiteWipeProgress: CGFloat = 0
        var snowmanFallOffset: CGFloat = 0
        var winterHillHeightFraction: CGFloat = AnimationConstants.initialWinterHillHeightFraction
        var winterHillColorMix: CGFloat = 0
        /// Fortlaufender Loop-Zähler (−1 während des einmaligen Intros).
        /// Dient als `.id()` für `SnowfallView`, damit deren interner
        /// Flocken-Zustand einmal pro Loop-Durchlauf frisch beginnt — und
        /// zwar konsistent über alle gleichzeitig existierenden
        /// MeadowView-Instanzen hinweg, weil er direkt aus der geteilten
        /// Zeit berechnet wird, nicht aus einer pro Instanz zufällig
        /// erzeugten UUID.
        var loopIndex: Int = -1
    }
    /// Berechnet den kompletten Render-Zustand als reine Funktion der seit
    /// `sharedAnimationStartDate` verstrichenen Zeit. Siehe
    /// Architekturkommentar am Dateianfang.
    private func renderState(at date: Date) -> RenderState {
        let elapsed = date.timeIntervalSince(animationStartDate)
        var state = RenderState()
        if elapsed < Timing.introTotalDuration {
            // Einmaliges Intro läuft noch — der restliche Loop-Zustand
            // bleibt auf seinen Ruhewerten (0 bzw. Anfangswerte).
            state.skyOpacity = progress(elapsed, start: Timing.introSkyStart, duration: Timing.introSkyDuration, .easeInOut)
            state.hillRise = progress(elapsed, start: Timing.introHillStart, duration: Timing.introHillDuration, .easeOut)
            state.loopIndex = -1
            return state
        }
        // Intro abgeschlossen — Himmel/Hügel bleiben dauerhaft eingeblendet
        // (entspricht: `resetLoopStartStates()` setzt diese beiden im Loop
        // bewusst NICHT zurück).
        state.skyOpacity = 1
        state.hillRise = 1
        let cycleElapsed = elapsed - Timing.introTotalDuration
        let tCycle = cycleElapsed.truncatingRemainder(dividingBy: Timing.cycleDuration)
        state.loopIndex = Int(cycleElapsed / Timing.cycleDuration)
        state.cycleStartReferenceTime = animationStartDate.timeIntervalSinceReferenceDate
            + Timing.introTotalDuration
            + Double(state.loopIndex) * Timing.cycleDuration
        state.flowersOpacity = progress(tCycle, start: Timing.flowersStart, duration: Timing.flowersDuration, .easeIn)
        // Berge: steigen, halten kurz, sinken wieder.
        if tCycle < Timing.mountainsRiseStart {
            state.mountainsRise = 0
        } else if tCycle < Timing.mountainsRiseStart + Timing.mountainsRiseDuration {
            state.mountainsRise = progress(tCycle, start: Timing.mountainsRiseStart, duration: Timing.mountainsRiseDuration, .easeOut)
        } else if tCycle < Timing.mountainsFallStart {
            state.mountainsRise = 1
        } else {
            state.mountainsRise = 1 - progress(tCycle, start: Timing.mountainsFallStart, duration: Timing.mountainsFallDuration, .easeIn)
        }
        // Wie in der früheren, flüssigen Version: Der boolesche Zielwert löst
        // im View eine einzige native SwiftUI-easeOut-Animation aus. waveRise
        // bleibt für das synchron eingeblendete Sand-Overlay zeitbasiert.
        state.waveActive = tCycle >= Timing.waveStart
        state.waveRise = progress(tCycle, start: Timing.waveStart, duration: Timing.waveDuration, .easeOut)
        // Ebenfalls wie in der funktionierenden Version: Die Phase läuft
        // unabhängig von der Abwärtsbewegung kontinuierlich über die Systemzeit.
        let waveTime = date.timeIntervalSinceReferenceDate
        state.wavePhase = CGFloat(waveTime.truncatingRemainder(dividingBy: 1000)) * waveSpeed
        state.sandOverlayOpacity = state.waveRise
        state.deepBlueRise = progress(tCycle, start: Timing.deepBlueStart, duration: Timing.deepBlueDuration, .easeOut)
        state.umbrellaFall = progress(tCycle, start: Timing.umbrellaStart, duration: Timing.umbrellaDuration, .easeOut)
        state.ballFall = progress(tCycle, start: Timing.ballStart, duration: Timing.ballDuration, .easeOut)
        // Eine einzige quadratische Kurve: Der Zoom beschleunigt vom ersten
        // Frame an kontinuierlich und wird bis zum Ende immer schneller.
        let zoomLinearProgress = progress(
            tCycle,
            start: Timing.zoomStart,
            duration: Timing.zoomDuration,
            .linear
        )
        state.zoomProgress = zoomLinearProgress * zoomLinearProgress
        // Direkt nach dem Zoom wird der Bildschirm ohne Übergangsanimation
        // vollständig rot. Danach wird der Herbstwald wie bisher eingeblendet.
        // Beim harten Szenenwechsel werden beide Ebenen zurückgesetzt.
        if tCycle < Timing.sceneSwitchTime {
            state.zoomOverlayOpacity = tCycle >= Timing.zoomEnd ? 1 : 0
            state.autumnForestOpacity = progress(tCycle, start: Timing.autumnStart, duration: Timing.autumnDuration, .easeInOut)
            let snowRaw = progress(tCycle, start: Timing.snowIncreaseStart, duration: Timing.snowIncreaseDuration, .linear)
            state.snowIntensity = snowRaw * snowRaw * (3 - 2 * snowRaw)
        } else {
            state.zoomOverlayOpacity = 0
            state.autumnForestOpacity = 0
            state.snowIntensity = 0
        }
        // Winterszene: erscheint schlagartig beim Szenenwechsel und bleibt
        // für den Rest des Loops sichtbar.
        state.winterSceneOpacity = tCycle >= Timing.sceneSwitchTime ? 1 : 0
        // Winter-Schneesturm: schlagartig an beim Szenenwechsel, schlagartig
        // aus, sobald er ausgelaufen ist.
        if tCycle < Timing.sceneSwitchTime {
            state.winterSnowIntensity = 0
        } else if tCycle < Timing.winterSnowOffTime {
            state.winterSnowIntensity = 1
        } else {
            state.winterSnowIntensity = 0
        }
        if tCycle < Timing.sceneSwitchTime {
            state.winterSnowEmissionIntensity = 0
        } else if tCycle < Timing.snowDecreaseStart {
            state.winterSnowEmissionIntensity = 1
        } else if tCycle < Timing.snowDecreaseStart + Timing.snowDecreaseDuration {
            let raw = progress(tCycle, start: Timing.snowDecreaseStart, duration: Timing.snowDecreaseDuration, .linear)
            let smooth = raw * raw * (3 - 2 * raw)
            state.winterSnowEmissionIntensity = 1 - smooth
        } else {
            state.winterSnowEmissionIntensity = 0
        }
        // Weißer Wisch: zwei Segmente (0 → 0.5, kurze Pause, 0.5 → 1).
        if tCycle < Timing.whiteWipe1Start {
            state.whiteWipeProgress = 0
        } else if tCycle < Timing.whiteWipe1Start + Timing.whiteWipe1Duration {
            state.whiteWipeProgress = progress(tCycle, start: Timing.whiteWipe1Start, duration: Timing.whiteWipe1Duration, .linear) * 0.5
        } else if tCycle < Timing.whiteWipe2Start {
            state.whiteWipeProgress = 0.5
        } else if tCycle < Timing.whiteWipe2Start + Timing.whiteWipe2Duration {
            state.whiteWipeProgress = 0.5 + progress(tCycle, start: Timing.whiteWipe2Start, duration: Timing.whiteWipe2Duration, .linear) * 0.5
        } else {
            state.whiteWipeProgress = 1
        }
        state.snowmanFallOffset = progress(tCycle, start: Timing.snowmanFallStart, duration: Timing.snowmanFallDuration, .easeIn)
            * AnimationConstants.snowmanSinkDistance
        let hillHeightProgress = progress(tCycle, start: Timing.hillGrowStart, duration: Timing.hillGrowDuration, .easeInOut)
        state.winterHillHeightFraction = AnimationConstants.initialWinterHillHeightFraction
            + hillHeightProgress * (AnimationConstants.summerHillHeightFraction - AnimationConstants.initialWinterHillHeightFraction)
        state.winterHillColorMix = progress(tCycle, start: Timing.hillColorStart, duration: Timing.hillColorDuration, .easeInOut)
        return state
    }
    /// Berechnet den Zoom-Ankerpunkt (als `UnitPoint` relativ zu `geo.size`)
    /// analytisch aus der bekannten, festen Geometrie des Sonnenschirms —
    /// statt ihn dynamisch per `PreferenceKey`-Messung zu bestimmen.
    ///
    /// HINTERGRUND: Die vorherige Messung lief über `overlayPreferenceValue`
    /// + `GeometryReader`, aktualisiert per `Task { @MainActor in ... }`.
    /// Das Problem: SwiftUI führt für einen gerade nicht sichtbaren Tab
    /// vermutlich keine (oder nur unregelmäßige) Layout-Durchläufe mehr
    /// aus — der gemessene Ankerpunkt blieb dadurch auf einem veralteten
    /// Stand stehen (z. B. noch während der Schirm gerade erst herunterfiel
    /// und seine Ruheposition noch nicht erreicht hatte, oder schlicht nie
    /// korrekt gemessen, wenn dieser Tab noch nie aktiv gelayoutet wurde).
    /// Kehrte man zu einem Tab zurück, während der Zoomfaktor durch die
    /// inzwischen verstrichene Zeit bereits stark vergrößert war, wurde um
    /// diesen falschen Punkt herum gezoomt — sichtbar als stark verzerrter,
    /// falsch positionierter Ausschnitt ohne erkennbare Wiese.
    ///
    /// Diese Funktion ist eine reine, synchrone Berechnung aus `geo.size`
    /// — unabhängig davon, ob und wie oft zuvor ein Layout-Durchlauf für
    /// diese View stattgefunden hat. Sie bildet exakt dieselbe Geometrie
    /// nach, die `BeachUmbrellaView` für Position, Rotation und den roten
    /// Streifen verwendet (Ruheposition bei `umbrellaFall = 1`).
    private func analyticZoomAnchor(in geo: GeometryProxy) -> UnitPoint {
        guard geo.size.width > 0, geo.size.height > 0 else { return .center }
        let canopyWidth = Double(BeachUmbrellaView.canopyWidth)
        let canopyHeight = Double(BeachUmbrellaView.canopyHeight)
        let totalHeight = Double(BeachUmbrellaView.totalHeight)
        // Mittelpunkt des Sonnenschirms in Ruhelage (umbrellaFall = 1),
        // identisch zur Positionierung weiter unten im Body.
        let centerX = Double(geo.size.width) * Double(umbrellaXFraction)
        let centerY = Double(umbrellaLandingY(in: geo))
        // Roter Markerpunkt, lokal zur Kuppel — identische Formel wie
        // `BeachUmbrellaView`s internem Streifen-Layout (7 Streifen,
        // mittlerer Streifen ist rot, r = 0.6 vom Kuppelradius
        // entfernt). Muss bei Änderungen dort synchron gehalten werden.
        let stripeCount = 7.0
        let redSegmentIndex = 3.0
        let step = 180.0 / stripeCount
        let angleDeg = (redSegmentIndex + 0.5) * step
        let rad = angleDeg * Double.pi / 180
        let r = 0.6
        let radiusX = canopyWidth / 2
        let radiusY = canopyHeight
        let localX = radiusX + r * radiusX * cos(rad)
        let localY = radiusY - r * radiusY * sin(rad)
        // Von Kuppel-lokalen Koordinaten in unrotierte Koordinaten relativ
        // zum Sonnenschirm-Mittelpunkt: Die Kuppel sitzt oben in der
        // (canopyWidth x totalHeight) großen Box, deren Mittelpunkt bei
        // `.position(center)` liegt.
        let unrotatedX = centerX - canopyWidth / 2 + localX
        let unrotatedY = centerY - totalHeight / 2 + localY
        // Die Rotation wird nach `.position()` angewendet und dreht daher im
        // Koordinatenraum des umgebenden ZStack um dessen Mittelpunkt. Diese
        // Reihenfolge bewahrt die ursprüngliche sichtbare Schirmposition.
        let rotationCenterX = Double(geo.size.width) / 2
        let rotationCenterY = Double(geo.size.height) / 2
        let dx = unrotatedX - rotationCenterX
        let dy = unrotatedY - rotationCenterY
        let theta = Double(umbrellaRestRotation) * Double.pi / 180
        let rotatedX = dx * cos(theta) - dy * sin(theta)
        let rotatedY = dx * sin(theta) + dy * cos(theta)
        let finalX = rotationCenterX + rotatedX
        let finalY = rotationCenterY + rotatedY
        return UnitPoint(x: finalX / Double(geo.size.width), y: finalY / Double(geo.size.height))
    }
    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            let meadowTopY = geo.size.height * 0.45
            TimelineView(.animation) { timeline in
                let state = renderState(at: timeline.date)
                let responsiveZoomTarget = max(
                    AnimationConstants.umbrellaZoomTargetScale,
                    geo.size.width / AnimationConstants.umbrellaZoomWidthDivisor
                )
                let responsiveZoomScale = 1
                    + state.zoomProgress * (responsiveZoomTarget - 1)
                ZStack {
                    ZStack {
                        adaptiveBackground.ignoresSafeArea()
                        skyColor
                            .ignoresSafeArea()
                            .opacity(state.skyOpacity)
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
                        .offset(y: (1 - state.mountainsRise) * geo.size.height * 1.2)
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
                            .opacity(state.flowersOpacity)
                            sandColor
                                .opacity(state.sandOverlayOpacity)
                        }
                        .frame(height: geo.size.height * 0.55)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .mask(
                            HillShape()
                                .frame(height: geo.size.height * 0.55)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        )
                        .ignoresSafeArea(edges: .bottom)
                        .offset(y: (1 - state.hillRise) * geo.size.height * 0.55)
                        MeadowWaveShape(
                            baseHeightFraction: 2.0 / 3.0,
                            amplitude: geo.size.height * 0.06,
                            frequency: 0.3,
                            phase: state.wavePhase
                        )
                        .fill(waveTurquoise)
                        .ignoresSafeArea()
                        .offset(y: state.waveActive ? 0 : -geo.size.height)
                        .animation(
                            state.waveActive
                                ? Animation.easeOut(duration: Timing.waveDuration)
                                : nil,
                            value: state.waveActive
                        )
                        Rectangle()
                            .fill(skyColor)
                            .frame(height: geo.size.height * 0.5)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .ignoresSafeArea(edges: .top)
                            .offset(y: -(1 - state.deepBlueRise) * geo.size.height * 0.5)
                        BeachUmbrellaView(canopyColor: umbrellaCanopyColor, poleColor: umbrellaPoleColor)
                            .position(
                                x: geo.size.width * umbrellaXFraction,
                                y: umbrellaLandingY(in: geo)
                            )
                            .rotationEffect(.degrees(umbrellaRestRotation))
                            .offset(y: -(1 - state.umbrellaFall) * geo.size.height)
                        Circle()
                            .fill(Color.white)
                            .frame(width: ballDiameter, height: ballDiameter)
                            .position(
                                x: geo.size.width * ballXFraction,
                                y: ballLandingY(in: geo) - (1 - state.ballFall) * geo.size.height
                            )
                    }
                    .scaleEffect(responsiveZoomScale, anchor: analyticZoomAnchor(in: geo))
                    umbrellaCanopyColor
                        .ignoresSafeArea()
                        .opacity(state.zoomOverlayOpacity)
                        .allowsHitTesting(false)
                    AutumnForestView()
                        .opacity(state.autumnForestOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    WinterMeadowView(
                        skyColor: skyColor,
                        hillHeightFraction: state.winterHillHeightFraction,
                        hillColor: mixedWinterHillColor(state.winterHillColorMix),
                        snowmanFallOffset: state.snowmanFallOffset
                    )
                    .opacity(state.winterSceneOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    SnowfallView(
                        intensity: max(state.snowIntensity, state.winterSnowIntensity),
                        emissionIntensity: state.snowIntensity > 0
                            ? state.snowIntensity
                            : state.winterSnowEmissionIntensity,
                        cycleStartReferenceTime: state.cycleStartReferenceTime,
                        snowIncreaseStart: Timing.snowIncreaseStart,
                        snowIncreaseDuration: Timing.snowIncreaseDuration,
                        snowDecreaseStart: Timing.snowDecreaseStart,
                        snowDecreaseDuration: Timing.snowDecreaseDuration
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    // Der Wisch verdeckt die Szene kurz vollständig. Genau in
                    // diesem Moment wechselt darunter der Herbst zum Winter
                    // (siehe `sceneSwitchTime` in `renderState(at:)`).
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(
                            x: geo.size.width / 2,
                            y: -geo.size.height / 2 + state.whiteWipeProgress * geo.size.height * 2
                        )
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    // Readability overlay adapts to light / dark mode
                    Rectangle()
                        .fill(colorScheme == .dark
                              ? Color.black.opacity(0.5)
                              : Color.white.opacity(0.5))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
    }
    private func umbrellaLandingY(in geo: GeometryProxy) -> CGFloat {
        geo.size.height * groundYFraction - BeachUmbrellaView.totalHeight / 2
    }
    private func ballLandingY(in geo: GeometryProxy) -> CGFloat {
        geo.size.height * groundYFraction - ballDiameter / 2
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
    private static let sharedForest = makeForest()
    private let leaves = Self.sharedForest.leaves
    private let trees = Self.sharedForest.trees

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(trees) { tree in
                    Rectangle()
                        .fill(Color(red: 0.35, green: 0.22, blue: 0.10))
                        .frame(width: tree.width, height: geo.size.height * tree.heightFraction)
                        .position(
                            x: geo.size.width * tree.xFraction,
                            y: geo.size.height * tree.yCenterFraction
                        )
                }

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
        }
    }

    private static func makeForest() -> (trees: [Tree], leaves: [Leaf]) {
        let treeCount = 7
        var generatedTrees: [Tree] = []
        for i in 0..<treeCount {
            let slot = (CGFloat(i) + 0.5) / CGFloat(treeCount)
            let jitterX = CGFloat.random(in: -0.04...0.04)
            let xFrac = min(max(slot + jitterX, 0.03), 0.97)
            let heightFrac = CGFloat.random(in: 0.45...0.85)
            let yCenterFrac = CGFloat.random(in: 0.30...0.55)
            let width = CGFloat.random(in: 10...18)
            let overlayChance = Double.random(in: 0.20...0.65)
            generatedTrees.append(Tree(
                xFraction: xFrac,
                heightFraction: heightFrac,
                yCenterFraction: yCenterFrac,
                width: width,
                overlayThreshold: overlayChance
            ))
        }

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
                let matchingTree = generatedTrees.first { tree in
                    abs(tree.xFraction - finalX) < 0.035
                }
                if let tree = matchingTree {
                    let treeTop = tree.yCenterFraction - (tree.heightFraction / 2.0)
                    let treeBottom = tree.yCenterFraction + (tree.heightFraction / 2.0)
                    if finalY >= treeTop && finalY <= treeBottom,
                       Double.random(in: 0...1) < tree.overlayThreshold {
                        continue
                    }
                }

                let colorBlurY = finalY + CGFloat.random(in: -0.15...0.15)
                let leafColor: Color
                let randomValue = Double.random(in: 0...1)
                if colorBlurY > 0.66 {
                    if randomValue < 0.33 {
                        leafColor = .orange
                    } else if randomValue < 0.66 {
                        leafColor = .yellow
                    } else {
                        leafColor = .red
                    }
                } else if colorBlurY > 0.44 {
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
        return (generatedTrees, generatedLeaves)
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
// MARK: - Schneefall (Canvas-basiert, zeitbasiert und instanzstabil)
private struct SnowfallView: View {
    let intensity: CGFloat
    let emissionIntensity: CGFloat
    let cycleStartReferenceTime: TimeInterval
    let snowIncreaseStart: TimeInterval
    let snowIncreaseDuration: TimeInterval
    let snowDecreaseStart: TimeInterval
    let snowDecreaseDuration: TimeInterval

    private let flakeDiameter: CGFloat = 22
    private let opacityBuckets = 12
    private static let sharedFlakes: [Snowflake] = (0..<8_000).map { _ in
        Snowflake(
            id: UUID(),
            xFraction: CGFloat.random(in: 0...1),
            groundXFraction: CGFloat.random(in: 0...1),
            groundYFraction: CGFloat.random(in: 0...1),
            activationThreshold: CGFloat.random(in: 0...1),
            retirementThreshold: CGFloat.random(in: 0...1),
            launchDelay: Double.random(in: 0...1.6),
            fallDuration: Double.random(in: 3.2...5.7),
            swayAmplitude: CGFloat.random(in: 3...11),
            swaySpeed: CGFloat.random(in: 0.55...1.1),
            swayPhase: CGFloat.random(in: 0...(2 * .pi))
        )
    }

    private var maximumFlakeCount: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 8_000 : 2_800
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let activeCount = targetFlakeCount(for: size)
                var flightPaths = [Int: Path]()
                var groundPaths = [Int: Path]()

                for flake in Self.sharedFlakes.prefix(activeCount) {
                    let launchTime = launchTime(for: flake)
                    let age = now - launchTime
                    guard age >= 0, isEmitting(flake, now: now, launchTime: launchTime) else { continue }

                    let cycleProgress = age.truncatingRemainder(dividingBy: flake.fallDuration) / flake.fallDuration
                    let y = -flakeDiameter + CGFloat(cycleProgress) * (size.height + flakeDiameter * 2)
                    let x = size.width * flake.xFraction
                        + sin(CGFloat(now) * flake.swaySpeed + flake.swayPhase) * flake.swayAmplitude
                    let flightRect = CGRect(
                        x: x - flakeDiameter / 2,
                        y: y - flakeDiameter / 2,
                        width: flakeDiameter,
                        height: flakeDiameter
                    )
                    let arrivalOpacity = min(1, CGFloat(age / 0.28))
                    let flightBucket = Int((arrivalOpacity * CGFloat(opacityBuckets)).rounded())
                    if flightBucket > 0 {
                        flightPaths[flightBucket, default: Path()].addEllipse(in: flightRect)
                    }

                    let settledAge = age - flake.fallDuration
                    guard settledAge >= 0 else { continue }
                    let settlingOpacity = min(1, CGFloat(settledAge / 1.2))
                    let groundRect = CGRect(
                        x: size.width * flake.groundXFraction - flakeDiameter / 2,
                        y: size.height * (0.67 + flake.groundYFraction * 0.33) - flakeDiameter / 2,
                        width: flakeDiameter,
                        height: flakeDiameter
                    )
                    let groundBucket = Int((settlingOpacity * CGFloat(opacityBuckets)).rounded())
                    if groundBucket > 0 {
                        groundPaths[groundBucket, default: Path()].addEllipse(in: groundRect)
                    }
                }

                for (bucket, path) in groundPaths {
                    context.fill(path, with: .color(.white.opacity(CGFloat(bucket) / CGFloat(opacityBuckets))))
                }
                for (bucket, path) in flightPaths {
                    context.fill(path, with: .color(.white.opacity(CGFloat(bucket) / CGFloat(opacityBuckets))))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func targetFlakeCount(for size: CGSize) -> Int {
        let density = min(max(intensity, 0), 1)
        let fullCoverageCount = min(
            maximumFlakeCount,
            Int((size.width * size.height) / (flakeDiameter * flakeDiameter) * 4)
        )
        return Int((CGFloat(fullCoverageCount) * density).rounded())
    }

    private func launchTime(for flake: Snowflake) -> TimeInterval {
        cycleStartReferenceTime
            + snowIncreaseStart
            + Double(flake.activationThreshold) * snowIncreaseDuration
            + flake.launchDelay
    }

    private func isEmitting(_ flake: Snowflake, now: TimeInterval, launchTime: TimeInterval) -> Bool {
        guard emissionIntensity < flake.retirementThreshold else { return true }
        let retirementTime = cycleStartReferenceTime
            + snowDecreaseStart
            + Double(1 - flake.retirementThreshold) * snowDecreaseDuration
        guard now >= retirementTime else { return true }
        let ageAtRetirement = retirementTime - launchTime
        guard ageAtRetirement >= 0 else { return false }
        let finalLandingTime = launchTime
            + (floor(ageAtRetirement / flake.fallDuration) + 1) * flake.fallDuration
        return now < finalLandingTime
    }

    private struct Snowflake: Identifiable {
        let id: UUID
        let xFraction: CGFloat
        let groundXFraction: CGFloat
        let groundYFraction: CGFloat
        let activationThreshold: CGFloat
        let retirementThreshold: CGFloat
        let launchDelay: TimeInterval
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
    // Streifenzahl und roter Segment-Index sind mit
    // `MeadowView.analyticZoomAnchor(in:)` synchron zu halten — diese
    // Funktion berechnet die Position des roten Streifens jetzt analytisch
    // statt sie hier per PreferenceKey zu messen (siehe Begründung dort).
    private let stripeCount = 7
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
