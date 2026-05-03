import SwiftUI

// MARK: - CookModeAnimationView

/// A looping, multi-phase full-screen animation used as the cook-mode background.
///
/// **Animation sequence (one full loop ~60 s):**
/// 1. Grey panel rises from the bottom.
/// 2. Blue wave appears and oscillates.
/// 3. Wave expands to fill the screen.
/// 4. Small bubbles appear, then fade.
/// 5. A large red tomato bubble grows from the centre.
/// 6. Black-hole transition reveals a beige background.
/// 7. Tomato shrinks; carrots, a second cucumber, and small tomatoes fly in.
/// 8. Camera zooms into the carrot, then the soup-ingredients scene fades in.
/// 9. Camera zooms into a cucumber slice; herb overlay fades in.
/// 10. Beige transition panel slides up; herb scene drops away.
/// 11. Second grey panel rises; everything resets for the next loop.
struct CookModeAnimationView: View {

    // MARK: State

    @State private var grayRise: CGFloat = 0
    @State private var waveRise: CGFloat = 0
    @State private var t: CGFloat = 0
    @State private var expand: CGFloat = 0
    @State private var showBubbles: Bool = false
    @State private var hideBubbles: Bool = false
    @State private var finalBubbleScale: CGFloat = 0
    @State private var finalBubbleOpacity: CGFloat = 0
    @State private var finalBubbleWhiteFill: CGFloat = 0
    @State private var finalBubbleWhiteOpacity: CGFloat = 1
    @State private var blackOverlayOpacity: CGFloat = 0
    @State private var blackHoleScale: CGFloat = 1.0
    @State private var beigeHoleScale: CGFloat = 1.0
    @State private var beigeOverlayOpacity: CGFloat = 0
    @State private var backgroundIsBeige: Bool = false
    @State private var hideWaveAndGray: Bool = false
    @State private var leafScale: CGFloat = 0
    @State private var leafOpacity: CGFloat = 0
    @State private var tomatoZoomScale: CGFloat = 1.0
    @State private var tomatoOffset: CGSize = .zero
    @State private var sceneZoom: CGFloat = 1.0
    @State private var sceneOffset: CGSize = .zero
    @State private var carrotScale: CGFloat = 0
    @State private var carrotOpacity: CGFloat = 0
    @State private var carrotOffset: CGSize = CGSize(width: -200, height: 0)
    @State private var carrot2Scale: CGFloat = 0
    @State private var carrot2Opacity: CGFloat = 0
    @State private var carrot2Offset: CGSize = CGSize(width: -200, height: 0)
    @State private var cucumberScale: CGFloat = 0
    @State private var cucumberOpacity: CGFloat = 0
    @State private var cucumberOffset: CGSize = CGSize(width: 200, height: 0)
    @State private var tomato2Scale: CGFloat = 1
    @State private var tomato2Opacity: CGFloat = 0
    @State private var tomato2Offset: CGSize = CGSize(width: -220, height: 0)
    @State private var tomato3Scale: CGFloat = 1
    @State private var tomato3Opacity: CGFloat = 0
    @State private var tomato3Offset: CGSize = CGSize(width: 0, height: 220)
    @State private var soupIngredientsOpacity: CGFloat = 0
    @State private var soupSceneZoom: CGFloat = 1.0
    @State private var soupSceneOffset: CGSize = .zero
    @State private var herbsOpacity: CGFloat = 0
    @State private var showHerbsScene: Bool = false
    @State private var herbsDropOffset: CGFloat = 0
    @State private var herbsDropOpacity: CGFloat = 1
    @State private var slideUpOffset: CGFloat = 0
    @State private var showOnlyHerbs: Bool = false
    @State private var beigeTransitionOpacity: CGFloat = 0
    @State private var beigeTransitionOffset: CGFloat = 0
    @State private var grayRise2: CGFloat = 0
    @State private var herbsDropOpacity2: CGFloat = 1

    // MARK: Constants

    let finalBubbleSize: CGFloat = 160
    let grayColor = Color(red: 0.9, green: 0.9, blue: 0.9)
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

    // MARK: Body

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            GeometryReader { geo in
                ZStack {

                    // ── Layer 1: Beige full-screen background ──────────────
                    if backgroundIsBeige {
                        Color(red: 0.96, green: 0.91, blue: 0.80).ignoresSafeArea()
                    }

                    // ── Layer 2: Main animation scene ──────────────────────
                    if !showOnlyHerbs {
                        mainScene(geo: geo)
                            .offset(y: slideUpOffset)
                    }

                    // ── Layer 3: Beige transition overlay ──────────────────
                    if beigeTransitionOpacity > 0 {
                        Color(red: 0.96, green: 0.91, blue: 0.80)
                            .ignoresSafeArea()
                            .opacity(beigeTransitionOpacity)
                            .offset(y: beigeTransitionOffset)
                            .allowsHitTesting(false)
                    }

                    // ── Layer 4: Herb scene ────────────────────────────────
                    if showHerbsScene {
                        SoupLayoutPreview()
                            .opacity(herbsOpacity)
                            .offset(y: herbsDropOffset)
                    }

                    // ── Layer 5: Second grey panel ─────────────────────────
                    VStack {
                        Spacer()
                        let restY       = geo.size.height * 0.52
                        let introOffset = (1 - grayRise2) * geo.size.height
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
    }

    // MARK: - Scene Builder

    /// Composes the main animation scene including wave, bubbles, masks, tomato, and vegetables.
    @ViewBuilder
    private func mainScene(geo: GeometryProxy) -> some View {
        ZStack {
            ZStack {
                ZStack(alignment: .bottom) {
                    if !hideWaveAndGray {

                        // Blue wave
                        WaveShape(t: t, expand: expand, waveRise: waveRise)
                            .fill(Color(red: 0.85, green: 0.95, blue: 1.0))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea()
                            .opacity(waveRise > 0 ? 1 : 0)
                            .onAppear { startAnimationSequence(geo: geo) }

                        // Grey base panel
                        let restY        = geo.size.height * 0.52
                        let introOffset  = (1 - grayRise) * geo.size.height
                        let expandOffset = geo.size.height * 0.55 * expand
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
                if showBubbles {
                    ForEach(bubbles) { bubble in
                        BubbleView(
                            x:     bubble.x,
                            y:     bubble.y,
                            delay: bubble.delay,
                            geo:   geo,
                            hide:  hideBubbles
                        )
                    }
                }

                // White fill behind the final tomato bubble
                if finalBubbleWhiteOpacity > 0 && finalBubbleOpacity > 0 {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: finalBubbleWhiteFill, height: finalBubbleWhiteFill)
                        .opacity(finalBubbleOpacity * finalBubbleWhiteOpacity)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // Black-hole mask overlay
                if blackOverlayOpacity > 0 {
                    blackHoleMask(geo: geo)
                }

                // Beige-hole mask overlay
                if beigeOverlayOpacity > 0 {
                    beigeHoleMask(geo: geo)
                }

                // ── Main tomato ────────────────────────────────────────
                ZStack {
                    Circle().fill(Color.red)
                        .frame(width: finalBubbleScale, height: finalBubbleScale)
                    Circle().strokeBorder(grayColor, lineWidth: 5)
                        .frame(width: finalBubbleScale, height: finalBubbleScale)
                        .opacity(finalBubbleScale < finalBubbleSize * 1.1 ? 1 : 0)
                    TomatoLeafView(scale: leafScale, opacity: leafOpacity)
                }
                .opacity(finalBubbleOpacity)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .scaleEffect(tomatoZoomScale)
                .offset(tomatoOffset)

                // ── Small tomato 2 ─────────────────────────────────────
                ZStack {
                    Circle().fill(Color.red)
                        .frame(width: finalBubbleSize * smallTomatoRatio,
                               height: finalBubbleSize * smallTomatoRatio)
                    TomatoLeafView(scale: smallLeafScale, opacity: 1)
                }
                .scaleEffect(tomato2Scale)
                .opacity(tomato2Opacity)
                .offset(tomato2Offset)
                .position(x: geo.size.width * 0.18, y: geo.size.height * 0.78)

                // ── Small tomato 3 ─────────────────────────────────────
                ZStack {
                    Circle().fill(Color.red)
                        .frame(width: finalBubbleSize * smallTomatoRatio,
                               height: finalBubbleSize * smallTomatoRatio)
                    TomatoLeafView(scale: smallLeafScale, opacity: 1)
                }
                .scaleEffect(tomato3Scale)
                .opacity(tomato3Opacity)
                .offset(tomato3Offset)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)

                CarrotView(scale: carrotScale, opacity: carrotOpacity)
                    .rotationEffect(.degrees(230))
                    .offset(carrotOffset)
                    .position(x: geo.size.width * 0.32, y: geo.size.height * 0.22)

                CarrotView(scale: carrot2Scale, opacity: carrot2Opacity)
                    .rotationEffect(.degrees(220))
                    .offset(carrot2Offset)
                    .position(x: geo.size.width * 0.4, y: geo.size.height * 0.12)

                CucumberView(scale: cucumberScale, opacity: cucumberOpacity)
                    .rotationEffect(.degrees(90))
                    .offset(cucumberOffset)
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.54)
            }
            .scaleEffect(sceneZoom)
            .offset(sceneOffset)

            // ── Soup ingredients scene ─────────────────────────────────
            if backgroundIsBeige {
                soupScene(geo: geo)
                    .scaleEffect(soupSceneZoom)
                    .offset(soupSceneOffset)
            }
        }
    }

    // MARK: - Sub-scene Builders

    /// Builds the soup-ingredients overlay shown after the beige transition.
    @ViewBuilder
    private func soupScene(geo: GeometryProxy) -> some View {
        ZStack {
            BubbleView(x: 0.25, y: 0.25, delay: 0.0, geo: geo, hide: false)
                .opacity(soupIngredientsOpacity)
            BubbleView(x: 0.30, y: 0.65, delay: 1.5, geo: geo, hide: false)
                .opacity(soupIngredientsOpacity)
            BubbleView(x: 0.75, y: 0.75, delay: 0.8, geo: geo, hide: false)
                .opacity(soupIngredientsOpacity)

            CucumberSliceView(size: 120).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.80, y: geo.size.height * 0.60)
            CucumberSliceView(size: 120).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.60, y: geo.size.height * 0.20)

            TomatoSliceView(size: 135).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.35, y: geo.size.height * 0.85)
            TomatoSliceView(size: 135).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.40, y: geo.size.height * 0.45)

            GarlicView(size: 40).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.08)
            GarlicView(size: 42).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.80, y: geo.size.height * 0.38)
            GarlicView(size: 44).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.15, y: geo.size.height * 0.25)
            GarlicView(size: 40).wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.30, y: geo.size.height * 0.65)

            MushroomSliceView(capSize: 75, stemWidth: 34, stemHeight: 28)
                .wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.20, y: geo.size.height * 0.10)
            MushroomSliceView(capSize: 75, stemWidth: 34, stemHeight: 28)
                .wiggle().opacity(soupIngredientsOpacity)
                .position(x: geo.size.width * 0.85, y: geo.size.height * 0.85)
        }
    }

    /// Builds the black rectangle-minus-circle mask used for the black-hole transition.
    @ViewBuilder
    private func blackHoleMask(geo: GeometryProxy) -> some View {
        GeometryReader { inner in
            Rectangle().fill(Color.black).ignoresSafeArea()
                .mask(
                    ZStack {
                        Rectangle().fill(Color.black)
                        Circle()
                            .frame(width: blackHoleScale + 10, height: blackHoleScale + 10)
                            .position(x: inner.size.width / 2, y: inner.size.height * 0.5)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .opacity(blackOverlayOpacity)
        }
        .ignoresSafeArea()
    }

    /// Builds the beige rectangle-minus-circle mask used to reveal the beige background.
    @ViewBuilder
    private func beigeHoleMask(geo: GeometryProxy) -> some View {
        GeometryReader { inner in
            Rectangle()
                .fill(Color(red: 0.96, green: 0.91, blue: 0.80))
                .ignoresSafeArea()
                .mask(
                    ZStack {
                        Rectangle().fill(Color.black)
                        Circle()
                            .frame(width: beigeHoleScale + 10, height: beigeHoleScale + 10)
                            .position(x: inner.size.width / 2, y: inner.size.height * 0.5)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .opacity(beigeOverlayOpacity)
        }
        .ignoresSafeArea()
    }

    // MARK: - Animation Sequence

    /// Starts the full animation loop. Called once via `.onAppear` on the wave shape.
    /// The sequence runs in an infinite `while true` Task, resetting all state at the end of each loop.
    private func startAnimationSequence(geo: GeometryProxy) {

        // Step 1: Grey panel rises immediately on appear
        withAnimation(.easeOut(duration: 2.5)) { grayRise = 1 }

        Task { @MainActor in
            while true {

                // Step 2: Blue wave appears and begins oscillating
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation(.easeOut(duration: 4.0)) { waveRise = 1 }
                withAnimation(.easeInOut(duration: 3.25).repeatForever(autoreverses: true)) { t = 1 }

                // Step 3: Wave expands horizontally
                try? await Task.sleep(for: .seconds(7.5))
                withAnimation(.easeInOut(duration: 2.5)) { expand = 1 }

                // Step 4: Small bubbles appear
                try? await Task.sleep(for: .seconds(2.0))
                showBubbles = true

                // Step 5: Small bubbles fade out
                try? await Task.sleep(for: .seconds(8.0))
                withAnimation(.easeOut(duration: 1.0)) { hideBubbles = true }

                // Step 6: Large tomato bubble grows from centre
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeIn(duration: 3.7)) { finalBubbleOpacity = 1 }
                withAnimation(.easeInOut(duration: 1.5)) { finalBubbleScale = finalBubbleSize }
                withAnimation(.easeInOut(duration: 6.0)) {
                    finalBubbleWhiteFill = max(geo.size.width, geo.size.height) * 2.5
                }

                // Step 7: Black-hole mask contracts to tomato size
                try? await Task.sleep(for: .seconds(4.0))
                blackHoleScale = max(geo.size.width, geo.size.height) * 2.5
                withAnimation(.easeIn(duration: 0.2)) { blackOverlayOpacity = 1 }
                withAnimation(.easeInOut(duration: 3.5)) { blackHoleScale = finalBubbleSize - 10 }

                // Step 8: Tomato grows → beige transition begins
                try? await Task.sleep(for: .seconds(4.0))
                withAnimation(.easeInOut(duration: 2.5)) { blackHoleScale = finalBubbleSize * 1.5 - 20 }
                withAnimation(.easeInOut(duration: 2.5)) { finalBubbleScale = finalBubbleSize * 1.5 }

                // Step 9: Beige background revealed via hole-mask
                try? await Task.sleep(for: .seconds(2.5))
                backgroundIsBeige = true
                hideWaveAndGray   = true
                withAnimation(.easeIn(duration: 0.3).delay(3.5)) { finalBubbleWhiteOpacity = 0 }
                beigeHoleScale = max(geo.size.width, geo.size.height) * 2.5
                withAnimation(.easeIn(duration: 0.3)) { beigeOverlayOpacity = 1 }
                withAnimation(.easeInOut(duration: 3.5)) { beigeHoleScale = finalBubbleSize * 1.5 - 20 }
                withAnimation(.easeOut(duration: 1.8).delay(1.5)) { leafOpacity = 1; leafScale = 1 }

                // Step 10: Tomato shrinks; vegetables fly in
                try? await Task.sleep(for: .seconds(4.0))
                blackOverlayOpacity = 0
                withAnimation(.easeInOut(duration: 2.0)) {
                    tomatoZoomScale     = 0.38
                    tomatoOffset        = CGSize(width: -geo.size.width * 0.15,
                                                height:  geo.size.height * 0.17)
                    beigeOverlayOpacity = 0
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.4)) {
                    carrotScale = 1; carrotOpacity = 1; carrotOffset = .zero
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.7)) {
                    carrot2Scale = 1; carrot2Opacity = 1; carrot2Offset = .zero
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.8)) {
                    cucumberScale = 1; cucumberOpacity = 1; cucumberOffset = .zero
                }
                withAnimation(.easeOut(duration: 1.2).delay(0.5)) {
                    tomato2Opacity = 1; tomato2Offset = .zero
                }
                withAnimation(.easeOut(duration: 1.2).delay(0.9)) {
                    tomato3Opacity = 1; tomato3Offset = .zero
                }

                // Step 11: Zoom into carrot 1
                try? await Task.sleep(for: .seconds(4.0))
                let targetX     = geo.size.width * 0.32
                let targetY     = geo.size.height * 0.22
                let centerX     = geo.size.width / 2
                let centerY     = geo.size.height / 2
                let zoomFactor: CGFloat = 50.0
                withAnimation(.easeIn(duration: 5.0)) {
                    sceneZoom   = zoomFactor
                    sceneOffset = CGSize(width:  (centerX - targetX) * zoomFactor,
                                        height: (centerY - targetY) * zoomFactor)
                }

                // Step 12: Soup ingredients scene fades in
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeIn(duration: 2.0)) { soupIngredientsOpacity = 1 }

                // Step 13: Zoom into cucumber slice
                try? await Task.sleep(for: .seconds(8.0))
                let gurkeX    = geo.size.width * 0.80
                let gurkeY    = geo.size.height * 0.60
                let gurkeZoom: CGFloat = 50.0
                withAnimation(.easeInOut(duration: 5.0)) {
                    soupSceneZoom   = gurkeZoom
                    soupSceneOffset = CGSize(width:  (geo.size.width  / 2 - gurkeX) * gurkeZoom,
                                            height: (geo.size.height / 2 - gurkeY) * gurkeZoom)
                }

                // Step 14: Beige overlay + herb scene fade in
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 3.5)) { beigeTransitionOpacity = 1.0 }
                showHerbsScene = true
                withAnimation(.easeIn(duration: 3.0).delay(0.5)) { herbsOpacity = 1.0 }

                // Step 15: Clean up behind the overlay; show only herbs
                try? await Task.sleep(for: .seconds(3.7))
                slideUpOffset     = -geo.size.height
                showOnlyHerbs     = true
                backgroundIsBeige = false

                // Step 16: Slide beige overlay upward and off screen
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 2.5)) { beigeTransitionOffset = -geo.size.height }
                try? await Task.sleep(for: .seconds(2.5))
                beigeTransitionOpacity = 0
                beigeTransitionOffset  = 0

                // Step 17: Second grey panel rises from the bottom
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeOut(duration: 2.5)) { grayRise2 = 1 }

                // Step 18: Herb scene drops off screen
                try? await Task.sleep(for: .seconds(4.0))
                withAnimation(.easeIn(duration: 1.8)) { herbsDropOffset = geo.size.height * 0.6 }

                // ── Loop reset ─────────────────────────────────────────
                try? await Task.sleep(for: .seconds(1.8))
                resetState()

                try? await Task.sleep(for: .seconds(0.1))
                // → Loop restarts from Step 2
            }
        }
    }

    // MARK: - Reset

    /// Resets all animation state variables to their initial values,
    /// preparing for the next loop iteration.
    private func resetState() {
        waveRise = 0; t = 0; expand = 0
        showBubbles = false; hideBubbles = false
        finalBubbleScale = 0; finalBubbleOpacity = 0
        finalBubbleWhiteFill = 0; finalBubbleWhiteOpacity = 1
        blackOverlayOpacity = 0; blackHoleScale = 1.0
        beigeHoleScale = 1.0; beigeOverlayOpacity = 0
        backgroundIsBeige = false; hideWaveAndGray = false
        leafScale = 0; leafOpacity = 0
        tomatoZoomScale = 1.0; tomatoOffset = .zero
        sceneZoom = 1.0; sceneOffset = .zero
        carrotScale = 0; carrotOpacity = 0; carrotOffset = CGSize(width: -200, height: 0)
        carrot2Scale = 0; carrot2Opacity = 0; carrot2Offset = CGSize(width: -200, height: 0)
        cucumberScale = 0; cucumberOpacity = 0; cucumberOffset = CGSize(width: 200, height: 0)
        tomato2Scale = 1; tomato2Opacity = 0; tomato2Offset = CGSize(width: -220, height: 0)
        tomato3Scale = 1; tomato3Opacity = 0; tomato3Offset = CGSize(width: 0, height: 220)
        soupIngredientsOpacity = 0; soupSceneZoom = 1.0; soupSceneOffset = .zero
        herbsOpacity = 0; showHerbsScene = false; herbsDropOffset = 0; herbsDropOpacity = 1
        slideUpOffset = 0; showOnlyHerbs = false
        beigeTransitionOpacity = 0; beigeTransitionOffset = 0
        herbsDropOpacity2 = 1; grayRise2 = 0
    }
}

#Preview {
    CookModeAnimationView()
}
