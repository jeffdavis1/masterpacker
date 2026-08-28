import Foundation
import MapKit

/// Wraps MKLocalSearchCompleter to drive a live-updating destination
/// suggestion list as the user types — the type-ahead behavior Apple Maps
/// uses. No API key/account or Apple capability needed; MapKit place
/// search doesn't require location permission (only the device's own
/// live location would).
@MainActor
final class DestinationSearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
    }

    func update(query: String) {
        completer.queryFragment = query
    }
}

extension DestinationSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.results = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}
