import SwiftUI
import AppKit

/// An editable combo box (dropdown of common values + free typing) for
/// fields that only ever take one of a handful of real-world values, like
/// "Camera Make" or "Film ISO" — wraps `NSComboBox` since SwiftUI has no
/// built-in equivalent.
struct ComboBoxField: NSViewRepresentable {
    @Binding var text: String
    let options: [String]
    var placeholder: String = ""
    /// Drawn as a border directly on the `NSComboBox`'s own layer, not a
    /// SwiftUI `.overlay()` — an overlay sitting on top of an
    /// `NSViewRepresentable`, even with `.allowsHitTesting(false)`, broke
    /// clicking into the combo box entirely. Painting the border on the
    /// real view's layer instead touches nothing about hit-testing.
    var isInvalid: Bool = false
    /// When set and present in `options`, the dropdown opens scrolled so
    /// this value sits in the middle of the visible list — see
    /// `comboBoxWillPopUp` below.
    var centerValue: String? = nil

    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.completes = true
        box.placeholderString = placeholder
        box.delegate = context.coordinator
        box.addItems(withObjectValues: options)
        box.stringValue = text
        box.wantsLayer = true
        return box
    }

    func updateNSView(_ box: NSComboBox, context: Context) {
        // Without this, the coordinator's delegate callbacks below keep
        // writing through the `text` binding captured back when this
        // specific `NSComboBox` was first created — SwiftUI reuses that same
        // AppKit view (and its `Coordinator`) across re-renders of the
        // "same" view identity, which includes switching the selected photo
        // in `MetadataEditorView` (it isn't `.id(item.id)`'d). Without
        // refreshing `parent` here, every combo box field kept editing
        // whichever photo was on screen when it was first created — e.g.
        // the first photo shown after import — no matter which one was
        // actually selected afterward.
        context.coordinator.parent = self
        if box.stringValue != text {
            box.stringValue = text
        }
        if box.placeholderString != placeholder {
            box.placeholderString = placeholder
        }
        let currentOptions = box.objectValues.compactMap { $0 as? String }
        if currentOptions != options {
            box.removeAllItems()
            box.addItems(withObjectValues: options)
        }
        box.layer?.borderColor = isInvalid ? NSColor.systemRed.cgColor : nil
        box.layer?.borderWidth = isInvalid ? 1.5 : 0
        box.layer?.cornerRadius = 5
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: ComboBoxField
        init(_ parent: ComboBoxField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            parent.text = box.stringValue
        }

        /// Fires just before the dropdown list appears — scrolls it so
        /// `centerValue` (e.g. "0 ev") lands in the middle of the visible
        /// rows instead of wherever the list's natural top-to-bottom order
        /// puts it, using `NSComboBox`'s own public scrolling API rather
        /// than touching `stringValue`/`selectItem` (either of which would
        /// overwrite the field's actual current value just to influence
        /// where the popup opens).
        func comboBoxWillPopUp(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox,
                  let centerValue = parent.centerValue,
                  let index = box.objectValues.firstIndex(where: { ($0 as? String) == centerValue }) else { return }
            let visible = box.numberOfVisibleItems
            let topIndex = max(0, index - visible / 2)
            box.scrollItemAtIndexToTop(topIndex)
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            // `box.objectValueOfSelectedItem` at this exact callback is more
            // reliable than `stringValue` — reading `stringValue` here was
            // the cause of a picked item flashing and then reverting: right
            // after this delegate call returns, AppKit's own popup-closing
            // logic can reassert the combo box's previous displayed text,
            // and since that happens outside of our code, `updateNSView`'s
            // "only push `text` in if it differs from `box.stringValue`"
            // check never notices the mismatch to correct it.
            let selected = (box.objectValueOfSelectedItem as? String) ?? box.stringValue
            parent.text = selected
            // A single reaffirm on the next run loop turn isn't reliable
            // enough — replacing a field that already held a value (versus
            // an empty one) does more work downstream (undo recording,
            // validation), which can shift the timing enough that AppKit's
            // internal reset wins the race against just one correction.
            // Reaffirming a few times over a short window makes sure our
            // value wins regardless of exactly when that reset happens;
            // each one is a no-op once the value is already right.
            for delay in [0, 0.03, 0.1, 0.25] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if box.stringValue != selected {
                        box.stringValue = selected
                    }
                }
            }
        }
    }
}
