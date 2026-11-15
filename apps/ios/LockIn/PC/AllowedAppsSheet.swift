import SwiftUI

/// Apps and sites that stay open on the PC while a session runs, for one task.
struct AllowedAppsSheet: View {
    let task: String?
    let done: () -> Void

    @State private var items: [String]
    @State private var draft = ""
    @FocusState private var typing: Bool

    init(task: String?, done: @escaping () -> Void) {
        self.task = task
        self.done = done
        _items = State(initialValue: AllowedApps.list(for: task))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FocusBackdrop(timing: nil, flash: nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Allowed on PC")
                            .font(Cream.rounded(26, .light))
                            .foregroundStyle(Matte.text)
                            .accessibilityAddTraits(.isHeader)
                        Text(task.map { "While you work on \($0)." } ?? "For sessions with no task.")
                            .font(Cream.rounded(14, .medium))
                            .foregroundStyle(Matte.textSoft)
                        VStack(spacing: 8) {
                            if items.isEmpty {
                                Text("Nothing added.")
                                    .font(Cream.rounded(16, .medium))
                                    .foregroundStyle(Matte.textSoft)
                                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Matte.tray))
                            }
                            ForEach(items, id: \.self) { name in
                                HStack {
                                    Text(name)
                                        .font(Cream.rounded(17, .medium))
                                        .foregroundStyle(Matte.text)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        items = AllowedApps.remove(name, for: task)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Matte.textQuiet)
                                            .frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("Remove \(name)")
                                }
                                .padding(.leading, 16)
                                .frame(minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Matte.tray))
                            }
                        }
                        HStack(spacing: 10) {
                            TextField("App or site, like Spotify", text: $draft)
                                .font(Cream.rounded(17, .medium))
                                .foregroundStyle(Matte.text)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($typing)
                                .submitLabel(.done)
                                .onSubmit(add)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 50)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Matte.tray))
                                .accessibilityIdentifier("allowed-field")
                            Button(action: add) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Matte.text)
                                    .frame(width: 50, height: 50)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Matte.tray))
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityLabel("Add")
                            .accessibilityIdentifier("allowed-add")
                        }
                    }
                    .padding(24)
                }
            }
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
        .preferredColorScheme(.light)
    }

    private func add() {
        items = AllowedApps.add(draft, for: task)
        draft = ""
        typing = false
    }
}
