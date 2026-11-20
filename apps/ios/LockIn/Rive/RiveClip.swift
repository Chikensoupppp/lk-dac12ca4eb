import SwiftUI
import RiveRuntime

/// One bundled Rive clip (built in apps/rive/<name>) with its default view model instance bound,
/// so the app can drive it: triggers, numbers and text.
///
/// Upstream flags `RiveViewModel` as deprecated in favour of the async `Rive` API. It still ships
/// in the 6.x runtime and is the form with a documented data-binding path, so the clips use it and
/// the compiler warnings are expected. Its initializers crash on a missing file or a wrong
/// artboard name, so `make` checks the bundle first and callers fall back to plain SwiftUI.
final class RiveClip: RiveViewModel {
    private(set) var boundInstance: RiveDataBindingViewModel.Instance?

    static func isBundled(_ file: String) -> Bool {
        Bundle.main.url(forResource: file, withExtension: "riv") != nil
    }

    static func make(_ file: String, artboard: String, stateMachine: String,
                     alignment: RiveAlignment = .center, autoPlay: Bool = true) -> RiveClip? {
        guard isBundled(file) else { return nil }
        return RiveClip(file, artboard: artboard, stateMachine: stateMachine, alignment: alignment, autoPlay: autoPlay)
    }

    private init(_ file: String, artboard: String, stateMachine: String, alignment: RiveAlignment, autoPlay: Bool) {
        super.init(fileName: file, stateMachineName: stateMachine, alignment: alignment, autoPlay: autoPlay,
                   artboardName: artboard, loadCdn: false)
        // Keep the instance: the runtime only applies property changes made through this one.
        riveModel?.enableAutoBind { [weak self] instance in self?.boundInstance = instance }
    }

    func set(_ name: String, text: String) {
        boundInstance?.stringProperty(fromPath: name)?.value = text
    }

    func fire(_ trigger: String) {
        boundInstance?.triggerProperty(fromPath: trigger)?.trigger()
    }

    func set(_ name: String, number: Float) {
        boundInstance?.numberProperty(fromPath: name)?.value = number
    }

    func set(_ name: String, flag: Bool) {
        boundInstance?.booleanProperty(fromPath: name)?.value = flag
    }
}

/// Creates the clip once per view (a `@StateObject`), not on every parent redraw.
final class RiveHolder: ObservableObject {
    let clip: RiveClip?

    init(file: String, artboard: String, stateMachine: String) {
        clip = RiveClip.make(file, artboard: artboard, stateMachine: stateMachine)
    }
}

/// The streak screen's five day stickers. A finished day pops in with its check drawn on, one
/// after another about 120 ms apart. Day names stay in SwiftUI under it.
struct RiveWeekRow: View {
    let done: [Bool]
    @StateObject private var holder = RiveHolder(file: "streak", artboard: "Week", stateMachine: "Week")

    var body: some View {
        if let clip = holder.clip {
            clip.view()
                .aspectRatio(5, contentMode: .fit)
                .task {
                    try? await Task.sleep(for: .milliseconds(300))
                    for (index, isDone) in done.prefix(5).enumerated() where isDone {
                        clip.set("day\(index + 1)", number: 1)
                        try? await Task.sleep(for: .milliseconds(120))
                    }
                }
        }
    }
}

/// The first-lock-in stamp: slams down onto the card with a splat and confetti, then rests tilted.
/// The clip is empty until `slam` fires, so nothing shows before it lands.
struct RiveStampView: View {
    @StateObject private var holder = RiveHolder(file: "stamp", artboard: "Stamp", stateMachine: "Stamp")

    var body: some View {
        if let clip = holder.clip {
            clip.view()
                .task {
                    try? await Task.sleep(for: .milliseconds(450))
                    clip.fire("slam")
                }
        }
    }
}

/// The pink brain cheering: a hop, star eyes and confetti when the view appears.
struct RiveBrainCheer: View {
    @StateObject private var holder = RiveHolder(file: "brain", artboard: "Brain", stateMachine: "Brain")

    var body: some View {
        if let clip = holder.clip {
            clip.view()
                .task {
                    try? await Task.sleep(for: .milliseconds(350))
                    clip.fire("win")
                }
        }
    }
}
