import SwiftUI

/// Shows every EXIF/TIFF/GPS/etc. tag ImageIO can read from a photo, grouped
/// by dictionary, with direct editing of individual tag values. Unlike the
/// curated editor above (which stages changes until "Save"), this reads and
/// writes the file directly — "Save" here takes effect immediately.
struct RawExifView: View {
    let item: PhotoItem
    @EnvironmentObject var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var groups: [RawTagGroup] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            Text("Editing here writes directly to the file. Values that can't be parsed back into a valid tag may be ignored.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
            if groups.isEmpty {
                Text("No raw EXIF/TIFF metadata found in this file.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($groups) { $group in
                        Section(group.name) {
                            ForEach($group.entries) { $entry in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.key)
                                        .frame(width: 190, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if entry.isEditable {
                                        TextField("", text: $entry.value)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        Text(entry.value)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .help("Not editable here")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(12)
            }
        }
        .frame(width: 580, height: 640)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Raw EXIF").font(.title3.bold())
                Text(item.filename).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reload") { load() }
            Button("Close") { dismiss() }
            Button {
                save()
            } label: {
                if isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(isSaving)
        }
        .padding(14)
    }

    private func load() {
        errorMessage = nil
        groups = ExifXMPService.readRawMetadata(from: item.url)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        do {
            try ExifXMPService.writeRaw(groups, to: item.url)
            library.reload(item)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
