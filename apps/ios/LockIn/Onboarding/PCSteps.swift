import SwiftUI

// Two slides about SwipeLater for Windows (free), right after "Every session fills in a day"
// (Brandon, 2026-11-20: "there are no slides about the PC"). Only what the PC app really does
// (docs/PC_BUDDY_PROTOCOL.md): the PC locks in with the phone, and the desk buddy asks before a
// distraction stays ("Back to work" minimizes it); a video or thread you'd rather keep goes to Later,
// which opens when the session is done. Same moving halftone field as the how-it-works slides. The
// user can tap the buddy's button; if not, it plays by itself. Reduce Motion shows the end state.

private enum Desk {
    static let screen = Color(hex: 0xF4F4F0)
    static let soft = Color(hex: 0x45473F)
    static let lines = Color(hex: 0x1B1B1B).opacity(0.13)
}

/// A laptop in the print style: an ink lid around a cream screen, and a thin base.
private struct PrintLaptop<Screen: View>: View {
    let width: CGFloat
    @ViewBuilder var screen: () -> Screen

    var height: CGFloat { (width * 0.64).rounded() }

    var body: some View {
        VStack(spacing: 0) {
            screen()
                .frame(width: width - 16, height: height - 16)
                .background(Desk.screen)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: width, height: height)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Ink.ink))
            UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 12, bottomTrailingRadius: 12,
                                   topTrailingRadius: 2, style: .continuous)
                .fill(Ink.ink)
                .frame(width: width + 36, height: 13)
                .overlay(alignment: .top) {
                    Capsule().fill(Color(hex: 0x55554F)).frame(width: 60, height: 4).padding(.top, 2)
                }
        }
        .compositingGroup()
        .shadow(color: Ink.ink.opacity(0.22), radius: 16, y: 14)
    }
}

/// A plain app window on the PC: a header with three dots and a title.
private struct DeskWindow<Content: View>: View {
    let title: String
    var fill: Color = .white
    var titleInk: Color = Desk.soft
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(titleInk.opacity(0.45)).frame(width: 4, height: 4) }
                Text(title).font(PrintFont.mono(7.5, .bold)).foregroundStyle(titleInk).padding(.leading, 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 15)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Ink.ink, lineWidth: 1.3))
    }
}

/// Grey text lines standing in for a document.
private struct DocLines: View {
    var widths: [CGFloat] = [0.92, 0.84, 0.95, 0.6, 0.88, 0.72]

    var body: some View {
        GeometryReader { g in
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                    Capsule().fill(Desk.lines).frame(width: g.size.width * w, height: 4)
                }
            }
        }
        .padding(8)
    }
}

/// The video standing in for a distraction: a thumbnail in the video icon's teal (`AppKindIcon.video`)
/// with a play button, so it reads as "a video" at a glance.
private struct VideoThumb: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: AppKindIcon.Kind.video.colors, startPoint: .top, endPoint: .bottom))
            Circle().fill(Color.white).frame(width: 26, height: 26)
                .overlay(Image(systemName: "play.fill").font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppKindIcon.Kind.video.colors[1]).offset(x: 1))
        }
        .padding(6)
    }
}

/// The desk buddy's speech bubble: one line, and its buttons.
private struct BuddyBubble<Buttons: View>: View {
    let text: String
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.ink)
                .fixedSize()
            buttons()
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Ink.ink, lineWidth: 1.5))
        .compositingGroup()
        .shadow(color: Ink.ink.opacity(0.18), radius: 6, y: 4)
    }
}

private func buddyPill(_ text: String, filled: Bool) -> some View {
    Text(text)
        .font(.system(size: 10.5, weight: .bold))
        .foregroundStyle(filled ? Color.white : Ink.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(filled ? Ink.ink : Color.white))
        .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 1.3))
        .fixedSize()
}

// MARK: Your PC locks in too.

/// The phone locks in, the PC follows (a LOCKED IN tag on its screen). A video site comes up over the
/// essay; the buddy pops up: "Is this for your work?" Tap "Back to work" (or wait) and the video
/// shrinks into the taskbar, the phone's line goes back to "PC: DOCS", the buddy says "Nice."
struct PCLockStep: View {
    let next: () -> Void
    @State private var laptopIn = false
    @State private var phoneIn = false
    @State private var linked = false
    @State private var distraction = false
    @State private var asking = false
    @State private var back = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let laptopWidth: CGFloat = 318

    var body: some View {
        PrintScaffold(step: 7, tag: "Your PC too", title: "Your PC\nlocks in too.", primaryTitle: "NEXT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.62, ripples: ripples))) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    PrintLaptop(width: Self.laptopWidth) { desk }
                        .frame(maxWidth: .infinity)
                        .offset(y: laptopIn ? 0 : 36)
                        .opacity(laptopIn ? 1 : 0)
                    miniPhone
                        .rotationEffect(.degrees(-6))
                        .offset(x: phoneIn ? -2 : -70, y: 28)
                        .opacity(phoneIn ? 1 : 0)
                }
                .padding(.top, 30)
                .padding(.bottom, 66)
                Text("FREE FOR WINDOWS \u{00B7} PAIR ONCE WITH A QR CODE")
                    .font(PrintFont.mono(11, .bold)).tracking(1)
                    .foregroundStyle(Desk.soft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .opacity(laptopIn ? 1 : 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("When you lock in on your phone, your PC locks in too. If a video site comes up, the desk buddy asks if it's for your work; Back to work puts it away. Free for Windows, pair once with a QR code.")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: linked)
        .sensoryFeedback(.impact(weight: .medium), trigger: asking)
        .sensoryFeedback(.success, trigger: back)
        .task { await play() }
    }

    /// The PC's screen: the essay, the video that pops up over it, the taskbar, and the buddy.
    private var desk: some View {
        let w = Self.laptopWidth - 16, h = (Self.laptopWidth * 0.64).rounded() - 16
        return ZStack(alignment: .topLeading) {
            DeskWindow(title: "Essay draft") { DocLines() }
                .frame(width: w * 0.66, height: h * 0.66)
                .offset(x: 12, y: 12)
            // The taskbar, where "Back to work" sends the video.
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(i == 2 && back ? Ink.blue : Ink.ink.opacity(0.18))
                        .frame(width: 10, height: 10)
                }
            }
            .frame(width: w, height: 16)
            .background(Ink.ink.opacity(0.06))
            .offset(y: h - 16)
            if linked {
                Text("LOCKED IN \u{00B7} 24:59")
                    .font(PrintFont.mono(7.5, .bold)).tracking(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Ink.blue))
                    .frame(width: w - 10, alignment: .trailing)
                    .offset(y: 8)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            DeskWindow(title: "Video site", fill: Color(hex: 0xDCE3F2)) { VideoThumb() }
                .frame(width: w * 0.58, height: h * 0.6)
                .scaleEffect(back ? 0.06 : (distraction ? 1 : 0.9), anchor: .bottom)
                .offset(x: w * 0.3, y: back ? h * 0.5 : 26)
                .opacity(distraction && !back ? 1 : 0)
            // The desk buddy, bottom right, with its question.
            ZStack(alignment: .bottomTrailing) {
                if asking {
                    BuddyBubble(text: back ? "Nice. Back to it!" : "Is this for your work?") {
                        if !back {
                            HStack(spacing: 5) {
                                buddyPill("It\u{2019}s for work", filled: false)
                                Button(action: goBack) { buddyPill("Back to work", filled: true) }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle().inset(by: -10))
                                    .accessibilityIdentifier("pc-back-to-work")
                            }
                        }
                    }
                    .padding(.trailing, 50)
                    .padding(.bottom, 30)
                    .transition(.scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity))
                }
                Image("BrainExact")
                    .resizable().scaledToFit()
                    .frame(width: 50)
                    .scaleEffect(asking ? 1 : 0.6, anchor: .bottom)
                    .opacity(asking ? 1 : 0)
                    .padding(.trailing, 4)
                    .padding(.bottom, 18)
            }
            .frame(width: w, height: h, alignment: .bottomTrailing)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    /// The phone in front of the laptop, showing the same session and what the PC is on.
    private var miniPhone: some View {
        let offTask = asking && !back
        return VStack(alignment: .leading, spacing: 2) {
            Text(linked ? "LOCKED IN" : "READY")
                .font(PrintFont.mono(7, .bold)).tracking(0.7)
                .foregroundStyle(linked ? Ink.blue : Desk.soft)
            Text("24:59").font(PrintFont.head(27)).foregroundStyle(Ink.ink).monospacedDigit()
            Text("Studying").font(.system(size: 9, weight: .semibold)).foregroundStyle(Ink.ink)
            Spacer(minLength: 0)
            Text(offTask ? "PC: VIDEO SITE" : "PC: DOCS")
                .font(PrintFont.mono(7, .bold)).tracking(0.4)
                .foregroundStyle(offTask ? OutlinedText.orangeDeep : Desk.soft)
                .lineLimit(1).minimumScaleFactor(0.7)
                .opacity(linked ? 1 : 0)
        }
        .padding(.horizontal, 9)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: 80, height: 154, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Desk.screen))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Ink.ink, lineWidth: 4))
        .overlay(alignment: .top) { Capsule().fill(Ink.ink).frame(width: 24, height: 6).padding(.top, 8) }
        .compositingGroup()
        .shadow(color: Ink.ink.opacity(0.25), radius: 10, y: 8)
    }

    private func goBack() {
        guard asking, !back else { return }
        if effectiveReduceMotion(systemReduceMotion) { back = true; return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { back = true }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.62, y: 0.5), start: .now, amp: 1.0))
    }

    private func play() async {
        if effectiveReduceMotion(systemReduceMotion) {
            laptopIn = true; phoneIn = true; linked = true; distraction = true; asking = true; back = true
            return
        }
        guard await printPause(0.3) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { laptopIn = true }
        guard await printPause(0.45) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phoneIn = true }
        guard await printPause(0.5) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { linked = true }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.6), start: .now, amp: 0.8))
        guard await printPause(0.8) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { distraction = true }
        guard await printPause(0.5) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { asking = true }
        // A moment to tap "Back to work" yourself; then it goes by itself.
        guard await printPause(2.4) else { return }
        goBack()
    }
}

// MARK: Save it for later.

/// The buddy asks "Save it for later?" over a video. Tap Save (or wait): the video flies into a
/// sunflower LATER card beside the laptop, two more links follow during the session, the session
/// bar fills to SESSION DONE, and the card opens into the list: they wait till you're done.
struct PCLaterStep: View {
    let next: () -> Void
    @State private var laptopIn = false
    @State private var asking = false
    @State private var saving = false
    @State private var shown = [false, false, false]
    @State private var sent = [false, false, false]
    @State private var saved = 0
    @State private var progress: CGFloat = 0
    @State private var done = false
    @State private var ripples: [FieldRipple] = []
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static let laptopWidth: CGFloat = 280
    private static let links: [(icon: AppKindIcon.Kind, title: String)] = [(.video, "Video \u{00B7} 12 min"),
                                                                             (.social, "Thread"),
                                                                             (.video, "Video \u{00B7} 8 min")]
    /// Where each link starts (the laptop's screen) and lands (the LATER card), in the stage below.
    private static let from = CGPoint(x: 120, y: 78)
    private static let to = CGPoint(x: 270, y: 208)

    var body: some View {
        PrintScaffold(step: 8, tag: "Your PC too", title: "Save it\nfor later.", primaryTitle: "NEXT", primaryAction: next,
                      backdrop: AnyView(HalftoneField(fadeStart: 0.62, ripples: ripples))) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    PrintLaptop(width: Self.laptopWidth) { desk }
                        .offset(x: 2, y: laptopIn ? 0 : 36)
                        .opacity(laptopIn ? 1 : 0)
                    // Below the laptop's lid (over its base only), so it never covers the buddy.
                    laterCard
                        .frame(width: 168, alignment: .topLeading)
                        .rotationEffect(.degrees(3))
                        .offset(x: 186, y: 186)
                        .opacity(laptopIn ? 1 : 0)
                    ForEach(0..<3, id: \.self) { i in
                        chip(Self.links[i])
                            .scaleEffect(sent[i] ? 0.5 : 1)
                            .position(sent[i] ? Self.to : Self.from)
                            .opacity(shown[i] && !sent[i] ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
                .padding(.top, 26)
                Text("VIDEOS AND THREADS \u{00B7} SAVED ON YOUR PC")
                    .font(PrintFont.mono(11, .bold)).tracking(1)
                    .foregroundStyle(Desk.soft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .opacity(laptopIn ? 1 : 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("On your PC, the desk buddy can save a video or thread for later. It waits in a Later list that opens when your session is done.")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: saved)
        .sensoryFeedback(.success, trigger: done)
        .task { await play() }
    }

    /// The PC's screen: the video and the buddy's offer; after saving, the essay and the session bar.
    private var desk: some View {
        let w = Self.laptopWidth - 16, h = (Self.laptopWidth * 0.64).rounded() - 16
        return ZStack(alignment: .topLeading) {
            DeskWindow(title: "Essay draft") { DocLines(widths: [0.9, 0.8, 0.94, 0.55]) }
                .frame(width: w - 24, height: h - 34)
                .offset(x: 12, y: 20)
            // The session bar along the top, filling to SESSION DONE.
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.ink.opacity(0.1))
                Capsule().fill(Ink.blue).frame(width: (w - 24) * progress)
            }
            .frame(width: w - 24, height: 5)
            .offset(x: 12, y: 8)
            if done {
                Text("SESSION DONE")
                    .font(PrintFont.head(20)).tracking(0.5)
                    .foregroundStyle(Ink.red)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.92)))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.red, lineWidth: 2.5))
                    .rotationEffect(.degrees(-8))
                    .frame(width: w, height: h)
                    .transition(.scale(scale: 1.8).combined(with: .opacity))
            }
            DeskWindow(title: "Video site", fill: Color(hex: 0xDCE3F2)) { VideoThumb() }
                .frame(width: w - 24, height: h - 34)
                .scaleEffect(saving ? 0.3 : 1, anchor: .center)
                .offset(x: 12, y: 20)
                .opacity(saving ? 0 : 1)
            ZStack(alignment: .bottomTrailing) {
                if asking && !saving {
                    BuddyBubble(text: "Save it for later?") {
                        Button(action: save) { buddyPill("Save for later", filled: true) }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle().inset(by: -10))
                            .accessibilityIdentifier("pc-save-later")
                    }
                    .padding(.trailing, 46)
                    .padding(.bottom, 14)
                    .transition(.scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity))
                }
                Image("BrainExact")
                    .resizable().scaledToFit()
                    .frame(width: 46)
                    .scaleEffect(asking ? 1 : 0.6, anchor: .bottom)
                    .opacity(asking ? 1 : 0)
                    .padding(.trailing, 2)
                    .padding(.bottom, 2)
            }
            .frame(width: w, height: h, alignment: .bottomTrailing)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    /// A sunflower card: LATER and a count; when the session is done it opens into the list.
    private var laterCard: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LATER").font(PrintFont.mono(11, .bold)).tracking(1.2)
                Spacer(minLength: 4)
                Text("\(saved)")
                    .font(PrintFont.head(22)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(saved)))
            }
            .foregroundStyle(Ink.ink)
            if done {
                ForEach(0..<saved, id: \.self) { i in
                    HStack(spacing: 6) {
                        AppKindIcon(kind: Self.links[i].icon, size: 20)
                        Text(Self.links[i].title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 2)
                        Text("Open").font(.system(size: 10, weight: .bold)).foregroundStyle(Ink.blue)
                    }
                    .foregroundStyle(Ink.ink)
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                Text(saved == 0 ? "Nothing yet" : "Waits till you\u{2019}re done")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Ink.ink.opacity(0.7))
            }
        }
        .padding(10)
        .background(shape.fill(Ink.sun))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 4))
        .keyframeAnimator(initialValue: CGFloat(1), trigger: saved) { view, s in
            view.scaleEffect(s)
        } keyframes: { _ in
            KeyframeTrack { CubicKeyframe(1.06, duration: 0.1); SpringKeyframe(1, duration: 0.3) }
        }
    }

    private func chip(_ link: (icon: AppKindIcon.Kind, title: String)) -> some View {
        HStack(spacing: 5) {
            AppKindIcon(kind: link.icon, size: 16)
            Text(link.title).font(.system(size: 11, weight: .bold)).foregroundStyle(Ink.ink)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 1.5))
        .fixedSize()
    }

    private func save() {
        guard asking, !saving else { return }
        Task { await sendAll() }
    }

    /// The first link (the video on screen), then two more during the session, then SESSION DONE.
    private func sendAll() async {
        if effectiveReduceMotion(systemReduceMotion) {
            saving = true; saved = 3; progress = 1; done = true
            return
        }
        withAnimation(.easeIn(duration: 0.25)) { saving = true }
        for i in 0..<3 {
            withAnimation(.easeOut(duration: 0.12)) { shown[i] = true }
            guard await printPause(i == 0 ? 0.2 : 0.12) else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { sent[i] = true }
            guard await printPause(0.45) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { saved = i + 1 }
            ripples.append(FieldRipple(origin: UnitPoint(x: 0.78, y: 0.6), start: .now, amp: 0.55, speed: 420))
            withAnimation(.linear(duration: 0.5)) { progress = CGFloat(i + 1) / 4 }
            guard await printPause(0.25) else { return }
        }
        withAnimation(.easeInOut(duration: 0.8)) { progress = 1 }
        guard await printPause(0.85) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { done = true }
        ripples.append(FieldRipple(origin: UnitPoint(x: 0.5, y: 0.5), start: .now, amp: 1.0))
    }

    private func play() async {
        if effectiveReduceMotion(systemReduceMotion) {
            laptopIn = true; asking = true
            await sendAll()
            return
        }
        guard await printPause(0.3) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { laptopIn = true }
        guard await printPause(0.6) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { asking = true }
        // A moment to tap "Save for later" yourself; then it goes by itself.
        guard await printPause(2.2) else { return }
        save()
    }
}
