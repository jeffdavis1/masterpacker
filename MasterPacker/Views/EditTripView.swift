import SwiftUI
import SwiftData

/// Edits a trip's fields in place — name, destination, dates, travel
/// method, activities, and notes, the same set AddTripView collects at
/// creation (travelers/pets are the one exception; managing who's on the
/// trip is its own separate piece of work). Uses local @State pre-filled
/// from the trip and commits on Save, so Cancel discards edits cleanly
/// rather than mutating the trip live as you type.
struct EditTripView: View {
    let trip: Trip
    /// Called after the trip is actually deleted — lets the presenter
    /// (TripDetailView, which is pushed on a NavigationStack rather than
    /// sheeted) pop itself too, since this view's own dismiss() only
    /// closes this Edit Trip sheet and would otherwise leave the caller
    /// showing a trip that no longer exists.
    var onDelete: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var travelMethod: TravelMethod
    @State private var selectedActivities: Set<Activity>
    @State private var notes: String
    @State private var isPresentingDeleteConfirmation = false

    init(trip: Trip, onDelete: @escaping () -> Void = {}) {
        self.trip = trip
        self.onDelete = onDelete
        _name = State(initialValue: trip.name)
        _destination = State(initialValue: trip.destination)
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _travelMethod = State(initialValue: trip.travelMethod)
        _selectedActivities = State(initialValue: trip.activities)
        _notes = State(initialValue: trip.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip name", text: $name)
                    DestinationField(destination: $destination)
                    QuickDateField(label: "Start", date: $startDate)
                    QuickDateField(label: "End", date: $endDate, minimumDate: startDate)
                    Picker("Travel method", selection: $travelMethod) {
                        ForEach(TravelMethod.allCases) { method in
                            Label(method.rawValue, systemImage: method.symbol).tag(method)
                        }
                    }
                }

                // Field parity with AddTripView — activities and notes
                // used to only be settable at trip creation, with no way
                // to change them afterward short of deleting and
                // recreating the whole trip. Traveler/pet membership is
                // deliberately NOT added here — that's its own separate,
                // larger piece of work (re-triggering always-pack items,
                // resyncing shared trips, etc.), tracked on its own
                // roadmap card.
                Section("Activities") {
                    ActivityChipGrid(selected: $selectedActivities)
                    TextField(
                        "Tell us about your trip. AI will make suggestions; the more you tell us the better the suggestions.",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }

                Section {
                    Button("Delete Trip", role: .destructive) {
                        isPresentingDeleteConfirmation = true
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
            .alert("Delete Trip?", isPresented: $isPresentingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteTrip() }
            } message: {
                Text(deleteWarningMessage)
            }
        }
    }

    private var deleteWarningMessage: String {
        if TripSharingService.shared.isShared(trip) {
            return "This trip is shared. Deleting it will also remove it from everyone you've shared it with. This can't be undone."
        }
        return "This can't be undone."
    }

    private func deleteTrip() {
        let wasShared = TripSharingService.shared.isShared(trip)
        Task {
            if wasShared {
                await TripSharingService.shared.stopSharing(trip)
            }
            NotificationManager.shared.cancelReminders(for: trip)
            modelContext.delete(trip)
            AnalyticsService.tripDeleted(wasShared: wasShared)
            dismiss()
            onDelete()
        }
    }

    private func save() {
        let destinationChanged = trip.destination != destination

        trip.name = name
        trip.destination = destination
        trip.startDate = startDate
        trip.endDate = endDate
        trip.travelMethod = travelMethod
        trip.activities = selectedActivities
        trip.notes = notes

        // A new destination invalidates the weather-change baseline — it
        // was tracking the old place, so the next check would otherwise
        // compare against somewhere else's forecast.
        if destinationChanged {
            NotificationManager.shared.resetWeatherBaseline(for: trip)
        }
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
            await TripSharingService.shared.resyncIfShared(trip)
        }

        dismiss()
    }
}

#Preview {
    let trip = Trip(name: "Preview Trip", destination: "Somewhere", startDate: .now, endDate: .now)
    return EditTripView(trip: trip)
        .modelContainer(for: [Trip.self], inMemory: true)
}
