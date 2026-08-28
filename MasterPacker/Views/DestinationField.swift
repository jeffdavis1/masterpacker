import SwiftUI
import MapKit

/// A destination text field with a live autocomplete dropdown (like Apple
/// Maps), instead of a bare free-text field — the user picks a validated
/// real place from suggestions rather than typing anything, which is what
/// makes weather lookups (and geocoding generally) reliable.
struct DestinationField: View {
    @Binding var destination: String
    @StateObject private var completer = DestinationSearchCompleter()
    @FocusState private var isFocused: Bool

    private var visibleResults: [MKLocalSearchCompletion] {
        Array(completer.results.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Destination", text: $destination)
                .focused($isFocused)
                .onChange(of: destination) { _, newValue in
                    completer.update(query: newValue)
                }

            if isFocused && !visibleResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleResults.enumerated()), id: \.offset) { index, result in
                        Button {
                            select(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < visibleResults.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func select(_ result: MKLocalSearchCompletion) {
        destination = result.subtitle.isEmpty ? result.title : "\(result.title), \(result.subtitle)"
        completer.update(query: "")
        isFocused = false
    }
}
