import SwiftUI
import SwiftData
import MapKit

/// Shows every trip's destination as a pin — past trips in navy, upcoming
/// trips in brand blue. `Trip.destination` is just a validated place-name
/// string, not stored coordinates, so each pin's location is resolved via
/// `WeatherService`'s shared geocoding cache (same lookup the weather
/// forecast already uses, so it's often already cached and instant).
struct TripMapView: View {
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var pins: [TripPin] = []
    @State private var isLoading = true
    @State private var selectedTrip: Trip?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if pins.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No mappable trips yet",
                        systemImage: "map",
                        description: Text("Add a trip with a recognized destination to see it here.")
                    )
                } else {
                    Map(position: $cameraPosition) {
                        ForEach(pins) { pin in
                            Annotation(pin.trip.name, coordinate: pin.coordinate) {
                                Button {
                                    selectedTrip = pin.trip
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 30, height: 30)
                                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(pin.isPast ? AppTheme.navy : AppTheme.brand)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trip Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
            .task {
                await loadPins()
            }
        }
    }

    private func loadPins() async {
        var result: [TripPin] = []
        for trip in trips {
            if let coordinate = await WeatherService.shared.coordinate(for: trip.destination) {
                result.append(TripPin(trip: trip, coordinate: coordinate))
            }
        }
        pins = result
        isLoading = false
    }
}

private struct TripPin: Identifiable {
    let trip: Trip
    let coordinate: CLLocationCoordinate2D

    var id: PersistentIdentifier { trip.persistentModelID }
    var isPast: Bool { trip.endDate < .now }
}

#Preview {
    TripMapView()
        .modelContainer(for: [Trip.self, PackingItem.self, Traveler.self, Pet.self], inMemory: true)
}
