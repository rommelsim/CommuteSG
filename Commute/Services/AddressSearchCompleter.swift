import Foundation
import MapKit
import Observation

/// MapKit autocomplete biased toward Singapore. Drives the suggestion list
/// in `PlaceEditorSheet` while the user types an address. Results appear
/// asynchronously via the `MKLocalSearchCompleterDelegate` callback; we
/// hop to MainActor before publishing so SwiftUI sees the change cleanly.
@MainActor
@Observable
final class AddressSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // Bias roughly to Singapore so local addresses dominate.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
            span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45)
        )
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completer.queryFragment = ""
            results = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    func clear() {
        completer.queryFragment = ""
        results = []
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let newResults = completer.results
        Task { @MainActor in
            self.results = newResults
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        // Silent — autocomplete failure shouldn't block the user from typing
        // their address manually.
    }
}
