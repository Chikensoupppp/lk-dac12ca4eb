import SwiftUI

/// The pencil cell at the end of the minutes row on the Focus screen: type how long this session
/// runs. Whole minutes, 1 to 480 (8 hours). It writes the same value the preset cells do.
struct CustomMinutesSheet: View {
    static let range = 1...480
    private static let step = 5

    let save: (Int) -> Void
    let close: () -> Void

    @State private var text: String
    @FocusState private var typing: Bool

    init(current: Int, save: @escaping (Int) -> Void, close: @escaping () -> Void) {
        self.save = save
        self.close = close
        _text = State(initialValue: String(min(max(current, Self.range.lowerBound), Self.range.upperBound)))
    }

    /// The typed value, or nil while the field is empty or out of range.
    private var minutes: Int? {
        guard let n = Int(text), Self.range.contains(n) else { return nil }
        return n
    }

    private var note: String {
        guard let m = minutes else { return "Pick 1 to \(Self.range.upperBound) minutes." }
        guard m >= 60 else { return " " }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("CUSTOM TIME")
                        .font(PrintFont.mono(11, .bold)).tracking(1.4)
                        .foregroundStyle(Ink.blue)
                    Spacer()
                    Button("Cancel", action: close)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Ink.ink)
                        .frame(minHeight: 44)
                }
                Text("HOW LONG\nTO LOCK IN?")
                    .font(PrintFont.head(44))
                    .lineSpacing(-5)
                    .foregroundStyle(Ink.ink)
                    .accessibilityAddTraits(.isHeader)
                entry
                Text(note)
                    .font(PrintFont.mono(13))
                    .foregroundStyle(minutes == nil ? Ink.red : Ink.soft)
                    .accessibilityHidden(minutes == nil && text.isEmpty)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Ink.paper.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button { if let m = minutes { save(m) } } label: { Text("SET") }
                .buttonStyle(PrintButtonStyle())
                .disabled(minutes == nil)
                .opacity(minutes == nil ? 0.35 : 1)
                .accessibilityIdentifier("custom-minutes-set")
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Ink.paper)
        }
        .preferredColorScheme(.light)
        .presentationDetents([.large])
        .onChange(of: text) { _, new in
            let digits = String(new.filter(\.isNumber).prefix(3))
            if digits != new { text = digits }
        }
        .task {
            // Let the sheet finish rising before the keyboard does.
            try? await Task.sleep(for: .milliseconds(450))
            typing = true
        }
    }

    private var entry: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return HStack {
            stepButton("minus", -Self.step)
            Spacer(minLength: 4)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .focused($typing)
                    .font(PrintFont.head(64))
                    .monospacedDigit()
                    .foregroundStyle(Ink.ink)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .accessibilityLabel("Minutes")
                    .accessibilityIdentifier("custom-minutes-field")
                Text("MIN")
                    .font(PrintFont.mono(13, .bold))
                    .foregroundStyle(Ink.soft)
            }
            .contentShape(Rectangle())
            .onTapGesture { typing = true }
            Spacer(minLength: 4)
            stepButton("plus", Self.step)
        }
        .padding(.horizontal, 14)
        .frame(height: 108)
        .background(shape.fill(Ink.receipt))
        .overlay(shape.strokeBorder(Ink.ink, lineWidth: 2))
        .background(shape.fill(Ink.ink).offset(y: 5))
    }

    private func stepButton(_ icon: String, _ delta: Int) -> some View {
        Button {
            let next = min(max((Int(text) ?? 0) + delta, Self.range.lowerBound), Self.range.upperBound)
            text = String(next)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Ink.ink)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.white))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "\(Self.step) minutes more" : "\(Self.step) minutes less")
    }
}
