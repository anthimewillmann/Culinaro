import SwiftUI

// MARK: - Architekturänderung: zeitbasiert statt zustandsbasiert (siehe MeadowView)
//
// Übernommen aus `MeadowView`: Der komplette Render-Zustand wird bei jedem
// Frame als reine Funktion der seit einem geteilten, für die App-Laufzeit
// festen Startzeitpunkt (`sharedAnimationStartDate`) verstrichenen Zeit neu
// berechnet (`renderState(at:size:)`) — statt als imperative `@State`-Sequenz
// aus verschachtelten `Task.sleep` + `withAnimation`-Aufrufen. Das macht die
// View resilient gegenüber Neuerzeugung (z. B. bei Tab-/Sheet-Wechsel): eine
// neu erzeugte Instanz "springt" direkt an die korrekte Stelle im Ablauf,
// statt wieder bei Schritt 1 zu beginnen. Die eigentlichen Animationswerte
// (Zeitpunkte, Dauern, Zielwerte) sind dabei unverändert aus der ehemaligen
// `startAnimationSequence()`-Sequenz übernommen — nur die Berechnungsart hat
// sich geändert.
//
// Einzige Ausnahme: `grayRise` (Schritt 1) läuft, genau wie im Original,
// EINMALIG anhand der absoluten verstrichenen Zeit statt anhand der
// zyklischen Loop-Zeit — im Original wurde `grayRise` nie in `resetState()`
// zurückgesetzt, lief also nur beim allerersten Erscheinen einmal hoch und
// blieb danach für immer bei 1, unabhängig vom Loop.
struct CookModeAnimationView: View {
    @EnvironmentObject private var stats: StatsStore

    /// Für die gesamte Prozesslaufzeit fester, von allen Instanzen geteilter
    /// Referenzzeitpunkt — siehe Architekturkommentar. `var` statt `let`,
    /// damit Deaktivieren/Wiederaktivieren der Animation ihn zurücksetzen
    /// kann (siehe `stats.cookModeAnimationEnabled`).
    private static var sharedAnimationStartDate = Date()

    /// Zeitpunkt, an dem die Animation zuletzt deaktiviert wurde — dient als
    /// eingefrorener Anzeige-Zeitpunkt, solange `stats.cookModeAnimationEnabled`
    /// `false` ist, damit kein `TimelineView`-Tick mehr läuft (echtes
    /// Stoppen, nicht nur unsichtbares Weiterlaufen).
    @State private var freezeDate: Date?

    // MARK: - Constants

    let finalBubbleSize: CGFloat = 160
    let grayColor = Color(red: 0.9, green: 0.9, blue: 0.9)
    private let beigeColor = Color(red: 0.96, green: 0.91, blue: 0.80)
    private let smallTomatoRatio: CGFloat = 0.5
    private var smallLeafScale: CGFloat { smallTomatoRatio * 0.75 }

    /// Nine randomly positioned bubbles with staggered delays.
    let bubbles: [Bubble] = (0..<9).map { i in
        Bubble(
            x:     CGFloat.random(in: 0.15...0.85),
            y:     CGFloat.random(in: 0.15...0.85),
            delay: Double(i) * 0.5
        )
    }

    private enum Easing { case linear, easeIn, easeOut, easeInOut }

    /// Identische Näherungsfunktion wie in `MeadowView` — siehe dort für die
    /// Begründung der Sinus- statt quadratischen Kurven bei `easeIn`/`easeOut`.
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

    /// Alle für einen Frame benötigten Render-Werte — ein Feld pro ehemaliger
    /// `@State`-Variable. `herbsDropOpacity`/`herbsDropOpacity2` aus dem
    /// Original wurden nicht übernommen: Sie wurden dort zwar deklariert und
    /// in `resetState()` zurückgesetzt, aber nirgends in der View gelesen —
    /// toter Zustand.
    private struct RenderState {
        var grayRise: CGFloat = 0
        var waveRise: CGFloat = 0
        var t: CGFloat = 0
        var expand: CGFloat = 0
        var showBubbles: Bool = false
        var hideBubbles: Bool = false
        var finalBubbleScale: CGFloat = 0
        var finalBubbleOpacity: CGFloat = 0
        var finalBubbleWhiteFill: CGFloat = 0
        var finalBubbleWhiteOpacity: CGFloat = 1
        var blackOverlayOpacity: CGFloat = 0
        var blackHoleScale: CGFloat = 1.0
        var beigeHoleScale: CGFloat = 1.0
        var beigeOverlayOpacity: CGFloat = 0
        var backgroundIsBeige: Bool = false
        var hideWaveAndGray: Bool = false
        var leafScale: CGFloat = 0
        var leafOpacity: CGFloat = 0
        var tomatoZoomScale: CGFloat = 1.0
        var tomatoOffset: CGSize = .zero
        var sceneZoom: CGFloat = 1.0
        var sceneOffset: CGSize = .zero
        var carrotScale: CGFloat = 0
        var carrotOpacity: CGFloat = 0
        var carrotOffset: CGSize = CGSize(width: -200, height: 0)
        var carrot2Scale: CGFloat = 0
        var carrot2Opacity: CGFloat = 0
        var carrot2Offset: CGSize = CGSize(width: -200, height: 0)
        var cucumberScale: CGFloat = 0
        var cucumberOpacity: CGFloat = 0
        var cucumberOffset: CGSize = CGSize(width: 200, height: 0)
        var tomato2Scale: CGFloat = 1
        var tomato2Opacity: CGFloat = 0
        var tomato2Offset: CGSize = CGSize(width: -220, height: 0)
        var tomato3Scale: CGFloat = 1
        var tomato3Opacity: CGFloat = 0
        var tomato3Offset: CGSize = CGSize(width: 0, height: 220)
        var soupIngredientsOpacity: CGFloat = 0
        var soupSceneZoom: CGFloat = 1.0
        var soupSceneOffset: CGSize = .zero
        var herbsOpacity: CGFloat = 0
        var showHerbsScene: Bool = false
        var herbsDropOffset: CGFloat = 0
        var slideUpOffset: CGFloat = 0
        var showOnlyHerbs: Bool = false
        var beigeTransitionOpacity: CGFloat = 0
        var beigeTransitionOffset: CGFloat = 0
        var grayRise2: CGFloat = 0
    }

    /// Berechnet den kompletten Render-Zustand als reine Funktion der seit
    /// `sharedAnimationStartDate` verstrichenen Zeit. Die benannten
    /// `stepN`-Zeitpunkte entsprechen exakt der kumulierten Summe der
    /// ehemaligen `try? await Task.sleep(...)`-Aufrufe in
    /// `startAnimationSequence()` — jeder `stepN` ist der Zeitpunkt, an dem
    /// der jeweilige `withAnimation`-Block im Original startete.
    private func renderState(at date: Date, size: CGSize) -> RenderState {
        let elapsed = date.timeIntervalSince(Self.sharedAnimationStartDate)
        var state = RenderState()

        // Schritt 1 (einmalig, siehe Architekturkommentar): läuft anhand der
        // absoluten Zeit, nicht der zyklischen Loop-Zeit, und bleibt danach
        // für immer bei 1.
        state.grayRise = progress(elapsed, start: 0, duration: 2.5, .easeOut)

        // iPad braucht an zwei Stellen (Schritt 12/14) etwas länger, bevor
        // die Suppen- bzw. Kräuterszene einblendet — identisch zum Original.
        let soupDelay: Double = UIDevice.current.userInterfaceIdiom == .pad ? 4.0 : 3.0
        let herbDelay: Double = UIDevice.current.userInterfaceIdiom == .pad ? 1.3 : 0.3

        let cycleDuration = 2.0 + 7.5 + 2.0 + 8.0 + 2.5 + 3.5 + 4.0 + 2.0 + 4.0 + 4.0
            + soupDelay + 8.0 + herbDelay + 3.7 + 1.5 + 2.5 + 1.5 + 4.0 + 1.8 + 0.1

        let tCycle = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        let step2 = 2.0
        let step3 = step2 + 7.5
        let step4 = step3 + 2.0
        let step5 = step4 + 8.0
        let step6 = step5 + 2.5
        let step7 = step6 + 3.5
        let step8 = step7 + 4.0
        let step9 = step8 + 2.0
        let step10 = step9 + 4.0
        let step11 = step10 + 4.0
        let step12 = step11 + soupDelay
        let step13 = step12 + 8.0
        let step14 = step13 + herbDelay
        let step15 = step14 + 3.7
        let step16a = step15 + 1.5
        let step16b = step16a + 2.5
        let step17 = step16b + 1.5
        let step18 = step17 + 4.0

        let bigHoleValue = max(size.width, size.height) * 2.5

        // Schritt 2: Welle steigt + oszilliert.
        state.waveRise = progress(tCycle, start: step2, duration: 4.0, .easeOut)
        if tCycle >= step2 {
            let period = 3.25 * 2
            let phase = (tCycle - step2).truncatingRemainder(dividingBy: period)
            state.t = phase <= 3.25
                ? progress(phase, start: 0, duration: 3.25, .easeInOut)
                : 1 - progress(phase - 3.25, start: 0, duration: 3.25, .easeInOut)
        }

        // Schritt 3: Welle expandiert horizontal.
        state.expand = progress(tCycle, start: step3, duration: 2.5, .easeInOut)

        // Schritt 4/5: kleine Blasen ein-/ausblenden.
        state.showBubbles = tCycle >= step4
        state.hideBubbles = tCycle >= step5

        // Schritt 6: große Tomaten-Blase wächst aus der Mitte.
        state.finalBubbleOpacity = progress(tCycle, start: step6, duration: 3.7, .easeIn)
        if tCycle < step8 {
            state.finalBubbleScale = progress(tCycle, start: step6, duration: 1.5, .easeInOut) * finalBubbleSize
        } else {
            let p = progress(tCycle, start: step8, duration: 2.5, .easeInOut)
            state.finalBubbleScale = finalBubbleSize + p * (finalBubbleSize * 1.5 - finalBubbleSize)
        }
        state.finalBubbleWhiteFill = progress(tCycle, start: step6, duration: 6.0, .easeInOut)
            * max(size.width, size.height) * 2.5
        state.finalBubbleWhiteOpacity = 1 - progress(tCycle, start: step9 + 3.5, duration: 0.3, .easeIn)

        // Schritt 7/10: schwarze Lochmaske zieht sich auf Tomatengröße
        // zusammen, springt bei Schritt 10 abrupt (ohne Animation) auf 0 —
        // identisch zum Original (`blackOverlayOpacity = 0` ohne `withAnimation`).
        if tCycle < step10 {
            state.blackOverlayOpacity = progress(tCycle, start: step7, duration: 0.2, .easeIn)
        }

        // Schritt 7/8: schwarze Lochmaske springt bei Schritt 7 instant auf
        // `bigHoleValue` (kein `withAnimation` im Original) und schrumpft
        // danach in zwei Phasen.
        if tCycle < step7 {
            state.blackHoleScale = 1.0
        } else if tCycle < step8 {
            let p = progress(tCycle, start: step7, duration: 3.5, .easeInOut)
            state.blackHoleScale = bigHoleValue + p * ((finalBubbleSize - 10) - bigHoleValue)
        } else {
            let p = progress(tCycle, start: step8, duration: 2.5, .easeInOut)
            state.blackHoleScale = (finalBubbleSize - 10) + p * ((finalBubbleSize * 1.5 - 20) - (finalBubbleSize - 10))
        }

        // Schritt 9: beige Lochmaske springt instant auf `bigHoleValue` und
        // schrumpft dann in einer Phase.
        if tCycle < step9 {
            state.beigeHoleScale = 1.0
        } else {
            let p = progress(tCycle, start: step9, duration: 3.5, .easeInOut)
            state.beigeHoleScale = bigHoleValue + p * ((finalBubbleSize * 1.5 - 20) - bigHoleValue)
        }

        // Schritt 9/10: beige Overlay-Opazität blendet ein, dann bei
        // Schritt 10 (Teil derselben `withAnimation`, die auch den Tomaten-
        // Zoom auslöst) wieder aus.
        if tCycle < step10 {
            state.beigeOverlayOpacity = progress(tCycle, start: step9, duration: 0.3, .easeIn)
        } else {
            state.beigeOverlayOpacity = 1 - progress(tCycle, start: step10, duration: 2.0, .easeInOut)
        }

        // Schritt 9/15: beiger Hintergrund sichtbar zwischen Schritt 9 und 15
        // (Original setzt `backgroundIsBeige = false` explizit in Schritt 15).
        state.backgroundIsBeige = tCycle >= step9 && tCycle < step15
        state.hideWaveAndGray = tCycle >= step9

        // Schritt 9: Tomatenkelch-Blatt blendet ein.
        state.leafScale = progress(tCycle, start: step9 + 1.5, duration: 1.8, .easeOut)
        state.leafOpacity = state.leafScale

        // Schritt 10: Tomate schrumpft/verschiebt sich; Gemüse fliegt ein.
        let tomatoShrinkP = progress(tCycle, start: step10, duration: 2.0, .easeInOut)
        state.tomatoZoomScale = 1 + tomatoShrinkP * (0.38 - 1)
        state.tomatoOffset = CGSize(
            width: -size.width * 0.15 * tomatoShrinkP,
            height: size.height * 0.17 * tomatoShrinkP
        )

        let carrotP = progress(tCycle, start: step10 + 0.4, duration: 1.5, .easeOut)
        state.carrotScale = carrotP
        state.carrotOpacity = carrotP
        state.carrotOffset = CGSize(width: -200 * (1 - carrotP), height: 0)

        let carrot2P = progress(tCycle, start: step10 + 0.7, duration: 1.5, .easeOut)
        state.carrot2Scale = carrot2P
        state.carrot2Opacity = carrot2P
        state.carrot2Offset = CGSize(width: -200 * (1 - carrot2P), height: 0)

        let cucumberP = progress(tCycle, start: step10 + 0.8, duration: 1.5, .easeOut)
        state.cucumberScale = cucumberP
        state.cucumberOpacity = cucumberP
        state.cucumberOffset = CGSize(width: 200 * (1 - cucumberP), height: 0)

        let tomato2P = progress(tCycle, start: step10 + 0.5, duration: 1.2, .easeOut)
        state.tomato2Opacity = tomato2P
        state.tomato2Offset = CGSize(width: -220 * (1 - tomato2P), height: 0)

        let tomato3P = progress(tCycle, start: step10 + 0.9, duration: 1.2, .easeOut)
        state.tomato3Opacity = tomato3P
        state.tomato3Offset = CGSize(width: 0, height: 220 * (1 - tomato3P))

        // Schritt 11: Zoom auf Karotte 1.
        let targetX = size.width * 0.32
        let targetY = size.height * 0.22
        let centerX = size.width / 2
        let centerY = size.height / 2
        let zoomFactor: CGFloat = 50.0
        let sceneZoomP = progress(tCycle, start: step11, duration: 5.0, .easeIn)
        state.sceneZoom = 1 + sceneZoomP * (zoomFactor - 1)
        state.sceneOffset = CGSize(
            width: (centerX - targetX) * zoomFactor * sceneZoomP,
            height: (centerY - targetY) * zoomFactor * sceneZoomP
        )

        // Schritt 12: Suppenzutaten-Szene blendet ein.
        state.soupIngredientsOpacity = progress(tCycle, start: step12, duration: 2.0, .easeIn)

        // Schritt 13: Zoom auf Gurkenscheibe.
        let gurkeX = size.width * 0.80
        let gurkeY = size.height * 0.60
        let gurkeZoom: CGFloat = 50.0
        let soupZoomP = progress(tCycle, start: step13, duration: 5.0, .easeInOut)
        state.soupSceneZoom = 1 + soupZoomP * (gurkeZoom - 1)
        state.soupSceneOffset = CGSize(
            width: (size.width / 2 - gurkeX) * gurkeZoom * soupZoomP,
            height: (size.height / 2 - gurkeY) * gurkeZoom * soupZoomP
        )

        // Schritt 14: beiges Overlay + Kräuterszene blenden ein.
        if tCycle < step16b {
            state.beigeTransitionOpacity = progress(tCycle, start: step14, duration: 3.5, .easeInOut)
        }
        state.showHerbsScene = tCycle >= step14
        state.herbsOpacity = progress(tCycle, start: step14 + 0.5, duration: 3.0, .easeIn)

        // Schritt 15: Hintergrund wird nach oben geschoben; nur noch Kräuter sichtbar.
        state.slideUpOffset = tCycle >= step15 ? -size.height : 0
        state.showOnlyHerbs = tCycle >= step15

        // Schritt 16: beiges Overlay schiebt sich nach oben aus dem Bild,
        // springt danach abrupt (ohne Animation) zurück auf 0 — identisch
        // zum Original.
        if tCycle < step16b {
            state.beigeTransitionOffset = progress(tCycle, start: step16a, duration: 2.5, .easeInOut) * (-size.height)
        }

        // Schritt 17: zweites graues Panel steigt von unten hoch.
        state.grayRise2 = progress(tCycle, start: step17, duration: 2.5, .easeOut)

        // Schritt 18: Kräuterszene fällt aus dem Bild.
        state.herbsDropOffset = progress(tCycle, start: step18, duration: 1.8, .easeIn) * size.height * 0.6

        return state
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            if stats.cookModeAnimationEnabled {
                TimelineView(.animation) { timeline in
                    let state = renderState(at: timeline.date, size: geo.size)
                    sceneContent(state: state, geo: geo)
                }
            } else {
                // Deaktiviert: kein `TimelineView` mehr, damit wirklich kein
                // weiterer Frame mehr berechnet wird — stattdessen ein
                // einzelner eingefrorener Frame vom Zeitpunkt der Deaktivierung.
                // Deaktiviert: kein `TimelineView` mehr — Fallback bewusst
                // `Self.sharedAnimationStartDate` statt `Date()` (siehe
                // MeadowView für die ausführliche Begründung): `onChange`
                // feuert nicht beim allerersten Erscheinen einer Instanz, die
                // die Animation bereits deaktiviert vorfindet, daher darf der
                // Fallback niemals eine live fortschreitende Uhrzeit sein.
                let state = renderState(at: freezeDate ?? Self.sharedAnimationStartDate, size: geo.size)
                sceneContent(state: state, geo: geo)
            }
        }
        .onChange(of: stats.cookModeAnimationEnabled) { _, isEnabled in
            if isEnabled {
                // Wieder aktiviert: geteilter Startzeitpunkt wird neu
                // gesetzt, wodurch die Animation von vorne beginnt.
                Self.sharedAnimationStartDate = Date()
                freezeDate = nil
            } else if freezeDate == nil {
                freezeDate = Date()
            }
        }
    }

    @ViewBuilder
    private func sceneContent(state: RenderState, geo: GeometryProxy) -> some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            ZStack {
                // ── Layer 1: Beige full-screen background ──────────────
                if state.backgroundIsBeige {
                    beigeColor.ignoresSafeArea()
                }

                // ── Layer 2: Main animation scene ──────────────────────
                if !state.showOnlyHerbs {
                    mainScene(state: state, geo: geo)
                        .offset(y: state.slideUpOffset)
                }

                // ── Layer 3: Beige transition overlay ──────────────────
                if state.beigeTransitionOpacity > 0 {
                    beigeColor
                        .ignoresSafeArea()
                        .opacity(state.beigeTransitionOpacity)
                        .offset(y: state.beigeTransitionOffset)
                        .allowsHitTesting(false)
                }

                // ── Layer 4: Herb scene ────────────────────────────────
                if state.showHerbsScene {
                    SoupLayoutPreview()
                        .opacity(state.herbsOpacity)
                        .offset(y: state.herbsDropOffset)
                }

                // ── Layer 5: Second grey panel ─────────────────────────
                VStack {
                    Spacer()
                    let restY = geo.size.height * 0.52
                    let introOffset = (1 - state.grayRise2) * geo.size.height
                    Rectangle()
                        .fill(grayColor)
                        .frame(height: restY)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, -50)
                        .offset(y: introOffset)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    // MARK: - Scene Builder

    /// Composes the main animation scene including wave, bubbles, masks, tomato, and vegetables.
    @ViewBuilder
    private func mainScene(state: RenderState, geo: GeometryProxy) -> some View {
        ZStack {
            ZStack {
                ZStack(alignment: .bottom) {
                    if !state.hideWaveAndGray {

                        // Blue wave
                        WaveShape(t: state.t, expand: state.expand, waveRise: state.waveRise)
                            .fill(Color(red: 0.85, green: 0.95, blue: 1.0))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea()
                            .opacity(state.waveRise > 0 ? 1 : 0)

                        // Grey base panel
                        let restY        = geo.size.height * 0.52
                        let introOffset  = (1 - state.grayRise) * geo.size.height
                        let expandOffset = geo.size.height * 0.55 * state.expand
                        Rectangle()
                            .fill(grayColor)
                            .frame(height: restY)
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea(edges: .bottom)
                            .padding(.bottom, -50)
                            .offset(y: introOffset + expandOffset)
                    }
                }

                // Small floating bubbles
                if state.showBubbles {
                    ForEach(bubbles) { bubble in
                        BubbleView(
                            x:     bubble.x,
                            y:     bubble.y,
                            delay: bubble.delay,
                            geo:   geo,
                            hide:  state.hideBubbles
                        )
                    }
                }

                // White fill behind the final tomato bubble
                if state.finalBubbleWhiteOpacity > 0 && state.finalBubbleOpacity > 0 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: state.finalBubbleWhiteFill, height: state.finalBubbleWhiteFill)
                        .opacity(state.finalBubbleOpacity * state.finalBubbleWhiteOpacity)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Black-hole mask overlay
                if state.blackOverlayOpacity > 0 {
                    holeMask(scale: state.blackHoleScale, color: .black, opacity: state.blackOverlayOpacity)
                }

                // Beige-hole mask overlay
                if state.beigeOverlayOpacity > 0 {
                    holeMask(scale: state.beigeHoleScale, color: beigeColor, opacity: state.beigeOverlayOpacity)
                }

                // ── Main tomato ────────────────────────────────────────────
                ZStack {
                    Circle().fill(Color.red)
                        .frame(width: state.finalBubbleScale, height: state.finalBubbleScale)
                    Circle().strokeBorder(grayColor, lineWidth: 5)
                        .frame(width: state.finalBubbleScale, height: state.finalBubbleScale)
                        .opacity(state.finalBubbleScale < finalBubbleSize * 1.1 ? 1 : 0)
                    TomatoLeafView(scale: state.leafScale, opacity: state.leafOpacity)
                }
                .opacity(state.finalBubbleOpacity)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .scaleEffect(state.tomatoZoomScale)
                .offset(state.tomatoOffset)

                // ── Small tomato 2 ─────────────────────────────────────────
                smallTomato(scale: state.tomato2Scale, opacity: state.tomato2Opacity, offset: state.tomato2Offset)
                    .position(x: geo.size.width * 0.18, y: geo.size.height * 0.78)

                // ── Small tomato 3 ─────────────────────────────────────────
                smallTomato(scale: state.tomato3Scale, opacity: state.tomato3Opacity, offset: state.tomato3Offset)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)

                CarrotView(scale: state.carrotScale, opacity: state.carrotOpacity)
                    .rotationEffect(.degrees(230))
                    .offset(state.carrotOffset)
                    .position(x: geo.size.width * 0.32, y: geo.size.height * 0.22)

                CarrotView(scale: state.carrot2Scale, opacity: state.carrot2Opacity)
                    .rotationEffect(.degrees(220))
                    .offset(state.carrot2Offset)
                    .position(x: geo.size.width * 0.4, y: geo.size.height * 0.12)

                CucumberView(scale: state.cucumberScale, opacity: state.cucumberOpacity)
                    .rotationEffect(.degrees(90))
                    .offset(state.cucumberOffset)
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.54)
            }
            .scaleEffect(state.sceneZoom)
            .offset(state.sceneOffset)

            // ── Soup ingredients scene ─────────────────────────────────────
            if state.backgroundIsBeige {
                soupScene(state: state, geo: geo)
                    .scaleEffect(state.soupSceneZoom)
                    .offset(state.soupSceneOffset)
            }
        }
    }

    // MARK: - Sub-scene Builders

    /// A small tomato used for the two secondary tomato instances — identical
    /// shape as the original inline duplicated `ZStack`s, now parameterised.
    @ViewBuilder
    private func smallTomato(scale: CGFloat, opacity: CGFloat, offset: CGSize) -> some View {
        ZStack {
            Circle().fill(Color.red)
                .frame(width: finalBubbleSize * smallTomatoRatio,
                       height: finalBubbleSize * smallTomatoRatio)
            TomatoLeafView(scale: smallLeafScale, opacity: 1)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(offset)
    }

    /// Builds the soup-ingredients overlay shown after the beige transition.
    @ViewBuilder
    private func soupScene(state: RenderState, geo: GeometryProxy) -> some View {
        ZStack {
            BubbleView(x: 0.25, y: 0.25, delay: 0.0, geo: geo, hide: false)
                .opacity(state.soupIngredientsOpacity)
            BubbleView(x: 0.30, y: 0.65, delay: 1.5, geo: geo, hide: false)
                .opacity(state.soupIngredientsOpacity)
            BubbleView(x: 0.75, y: 0.75, delay: 0.8, geo: geo, hide: false)
                .opacity(state.soupIngredientsOpacity)

            CucumberSliceView(size: 120).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.80, y: geo.size.height * 0.60)
            CucumberSliceView(size: 120).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.60, y: geo.size.height * 0.20)

            TomatoSliceView(size: 135).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.35, y: geo.size.height * 0.85)
            TomatoSliceView(size: 135).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.40, y: geo.size.height * 0.45)

            GarlicView(size: 40).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.08)
            GarlicView(size: 42).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.80, y: geo.size.height * 0.38)
            GarlicView(size: 44).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.15, y: geo.size.height * 0.25)
            GarlicView(size: 40).wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.30, y: geo.size.height * 0.65)

            MushroomSliceView(capSize: 75, stemWidth: 34, stemHeight: 28)
                .wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.20, y: geo.size.height * 0.10)
            MushroomSliceView(capSize: 75, stemWidth: 34, stemHeight: 28)
                .wiggle().opacity(state.soupIngredientsOpacity)
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.85)
        }
    }

    /// Builds the rectangle-minus-circle mask used for both the black-hole
    /// and beige-hole transitions — parameterised by fill color instead of
    /// two near-duplicate `blackHoleMask`/`beigeHoleMask` functions.
    @ViewBuilder
    private func holeMask(scale: CGFloat, color: Color, opacity: CGFloat) -> some View {
        GeometryReader { inner in
            Rectangle().fill(color).ignoresSafeArea()
                .mask(
                    ZStack {
                        Rectangle().fill(Color.black)
                        Circle()
                            .frame(width: scale + 10, height: scale + 10)
                            .position(x: inner.size.width / 2, y: inner.size.height * 0.5)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .opacity(opacity)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    CookModeAnimationView()
        .environmentObject(StatsStore())
}
