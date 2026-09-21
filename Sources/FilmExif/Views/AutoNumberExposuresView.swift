import SwiftUI

/// Assigns sequential frame numbers to every photo in `items` at once —
/// e.g. numbering a whole roll 1, 2, 3... instead of typing each by hand.
struct AutoNumberExposuresView: View {
    let items: [PhotoItem]
    @Environment(\.dismiss) private var dismiss

    @State private var startNumber = 1
    @State private var orderBy: OrderOption = .filename
    @State private var direction: Direction = .ascending

    private enum OrderOption: String, CaseIterable, Identifiable {
        case filename, captureTime
        var id: String { rawValue }
        var title: String {
            self == .filename ? "File Name" : "Capture Time"
        }
    }

    private enum Direction: String, CaseIterable, Identifiable {
        case ascending, descending
        var id: String { rawValue }
        var title: String {
            self == .ascending ? "Ascending" : "Descending"
        }
    }

    /// The current settings' effect, computed live so the list below
    /// updates immediately as `orderBy`/`direction`/`startNumber` change,
    /// before anything is actually applied to the photos.
    private var preview: [(item: PhotoItem, number: Int)] {
        var ordered = items
        switch orderBy {
        case .filename:
            ordered.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .captureTime:
            ordered.sort { ($0.edited.dateTimeOriginal ?? .distantPast) < ($1.edited.dateTimeOriginal ?? .distantPast) }
        }
        if direction == .descending { ordered.reverse() }
        return ordered.enumerated().map { offset, item in (item, startNumber + offset) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // A real, standalone title — not row content or a Section
            // header inside either Form below.
            Text("Auto Frame Numbers")
                .font(.title3.bold())
            Text("Assigns sequential frame numbers to all \(items.count) selected photos.")
                .font(.callout)
                .foregroundStyle(.secondary)

            // "Settings" and "Preview" are two separate `Form`s at the same
            // level, not two Sections of one Form — so sizing one (Preview,
            // below) doesn't have to affect the other, and each can be
            // given its own layout behavior. They're in their own nested
            // VStack with a tighter spacing than the outer one, so the gap
            // between just these two shrinks without also shrinking the
            // title/description or preview/buttons spacing.
            VStack(spacing: 4) {
                Form {
                    Section("Settings") {
                        Picker("Order by", selection: $orderBy) {
                            ForEach(OrderOption.allCases) { option in
                                Text(LocalizedStringKey(option.title)).tag(option)
                            }
                        }
                        .tint(.primary)
                        Picker("Direction", selection: $direction) {
                            ForEach(Direction.allCases) { option in
                                Text(LocalizedStringKey(option.title)).tag(option)
                            }
                        }
                        .tint(.primary)
                        // A `TextField` (not a `Stepper`) so you can type
                        // the exact number directly, e.g. jump straight to
                        // 24.
                        TextField("Start at", value: $startNumber, format: .number)
                    }
                }
                .formStyle(.grouped)
                // Only its own natural (3-row) height — the remaining
                // space in the fixed-height window below goes to Preview.
                .fixedSize(horizontal: false, vertical: true)

                Form {
                    Section("Preview") {
                        ForEach(preview, id: \.item.id) { entry in
                            HStack {
                                Text(entry.item.filename)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(entry.number)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Apply") {
                    apply()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
        .frame(width: 420, height: 520)
    }

    private func apply() {
        for entry in preview {
            entry.item.edited.roll.frameNumber = String(entry.number)
        }
    }
}
