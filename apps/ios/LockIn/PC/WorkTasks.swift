import SwiftUI

/// "What are you working on?" The chosen task goes to the PC with the session start, and the PC
/// opens the workspace saved under the same name. Names only live here; the apps, files and
/// sites for each task are set up on the PC.
@MainActor
final class WorkTaskStore: ObservableObject {
    private static let tasksKey = "lockin.tasks.v1"
    private static let selectedKey = "lockin.tasks.selected.v1"
    static let starters = ["Studying", "Homework", "Work", "Writing", "Reading"]
    static let maxLength = 28

    @Published private(set) var tasks: [String]
    @Published var selected: String? { didSet { defaults.set(selected, forKey: Self.selectedKey) } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tasks = defaults.stringArray(forKey: Self.tasksKey) ?? Self.starters
        let saved = defaults.string(forKey: Self.selectedKey)
        selected = saved.flatMap { tasks.contains($0) ? $0 : nil }
    }

    /// Adds a task (trimmed, no duplicates) and selects it.
    func add(_ name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
        guard !clean.isEmpty else { return }
        if let same = tasks.first(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
            selected = same
            return
        }
        tasks.append(clean)
        save()
        selected = clean
    }

    func remove(_ name: String) {
        tasks.removeAll { $0 == name }
        if selected == name { selected = nil }
        save()
    }

    private func save() { defaults.set(tasks, forKey: Self.tasksKey) }
}

/// The pill above the minutes: "WORKING ON · STUDYING". Opens the picker.
struct WorkTaskPill: View {
    @ObservedObject var tasks: WorkTaskStore
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("WORKING ON")
                    .font(Cream.rounded(11, .semibold)).tracking(2)
                    .foregroundStyle(Matte.textSoft)
                Text((tasks.selected ?? "Pick one").uppercased())
                    .font(Cream.rounded(12, .bold)).tracking(1.5)
                    .foregroundStyle(tasks.selected == nil ? Matte.textSoft : Matte.text)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Matte.textQuiet)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(Capsule().fill(Matte.tray).overlay(Capsule().strokeBorder(Matte.edge, lineWidth: 1)))
            .frame(minHeight: 44)
        }
        .accessibilityLabel(tasks.selected.map { "Working on \($0)" } ?? "Pick what you are working on")
        .accessibilityIdentifier("work-task")
    }
}

/// Pick, add or remove tasks.
struct WorkTaskSheet: View {
    @ObservedObject var tasks: WorkTaskStore
    let done: () -> Void
    @State private var draft = ""
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                FocusBackdrop(timing: nil, flash: nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("What are you working on?")
                            .font(Cream.rounded(26, .light))
                            .foregroundStyle(Matte.text)
                        VStack(spacing: 8) {
                            ForEach(tasks.tasks, id: \.self) { name in
                                row(name)
                            }
                            row(nil)
                        }
                        HStack(spacing: 10) {
                            TextField("New task", text: $draft)
                                .font(Cream.rounded(17, .medium))
                                .foregroundStyle(Matte.text)
                                .focused($typing)
                                .submitLabel(.done)
                                .onSubmit(addDraft)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Matte.tray))
                            Button(action: addDraft) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Matte.text)
                                    .frame(width: 50, height: 50)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Matte.tray))
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityLabel("Add task")
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                        .font(Cream.rounded(17, .semibold))
                        .foregroundStyle(Matte.textQuiet)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addDraft() {
        tasks.add(draft)
        draft = ""
        typing = false
    }

    /// One task row; nil is "No task".
    private func row(_ name: String?) -> some View {
        let on = tasks.selected == name
        return Button { tasks.selected = name } label: {
            HStack {
                Text(name ?? "No task")
                    .font(Cream.rounded(17, on ? .semibold : .medium))
                    .foregroundStyle(name == nil ? Matte.textSoft : Matte.text)
                Spacer()
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Matte.text)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 16).fill(on ? Matte.chipHigh : Matte.tray))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let name {
                Button(role: .destructive) { tasks.remove(name) } label: { Label("Remove", systemImage: "trash") }
            }
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
