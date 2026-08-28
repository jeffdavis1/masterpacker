import SwiftUI
import SwiftData

/// Edits a trip's basic details (name, destination, dates, travel method)
/// in place. Uses local @State pre-filled from the trip and commits on
/// Save, so Cancel discards edits cleanly rather than mutating the trip
/// live as you type.
struct EditTripView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var travelMethod: TravelMethod

    init(trip: Trip) {
        self.trip = trip
        _name = State(initialValue: trip.name)
        _destination = State(initialValue: trip.destination)
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _travelMethod = State(initialValue: trip.travelMethod)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip name", text: $name)
                    DestinationField(destination: $destination)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                    Picker("Travel method", selection: $travelMethod) {
                        ForEach(TravelMethod.allCases) { method in
                            Label(method.rawValue, systemImage: method.symbol).tag(method)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let destinationChanged = trip.destination != destination

        trip.name = name
        trip.destination = destination
        trip.startDate = startDate
        trip.endDate = endDate
        trip.travelMethod = travelMethod

        // A new destination invalidates the weather-change baseline — it
        // was tracking the old place, so the next check would otherwise
        // compare against somewhere else's forecast.
        if destinationChanged {
            NotificationManager.shared.resetWeatherBaseline(for: trip)
        }
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
        }

        dismiss()
    }
}

#Preview {
    let trip = Trip(name: "Preview Trip", destination: "Somewhere", startDate: .now, endDate: .now)
    return EditTripView(trip: trip)
        .modelContainer(for: [Trip.self], inMemory: true)
}
