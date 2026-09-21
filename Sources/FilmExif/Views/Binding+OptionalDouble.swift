import SwiftUI

extension Binding where Value == Double? {
    /// A text-field-friendly view onto an optional Double: empty string
    /// when nil, parses back to nil for empty/invalid input.
    var asOptionalText: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue.map { String($0) } ?? "" },
            set: { self.wrappedValue = Double($0) }
        )
    }
}
