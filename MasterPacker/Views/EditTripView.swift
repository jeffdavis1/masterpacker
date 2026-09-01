import SwiftUI
import SwiftData

/// Edits a trip's fields in place — name, destination, dates, travel
/// method, activities, notes, and who's going, the same set AddTripView
/// collects at creation. Most fields use local @State pre-filled from the
/// trip and commit on Save, so Cancel discards those edits cleanly rather
/// than mutating the trip live as you type — traveler/pet membership is
/// the one exception, applied immediately when added or removed (same as
/// ProfileListView's own delete-swipe), since staging real model
/// inserts/deletes cleanly behind a Cancel button is a lot of complexity
/// for a screen that's already meant to read as "manage the list," not
/// "draft changes to review."
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
    @State private var isPresentingTravelerChooser = false
    @State private var newTravelerProfiles: [TravelerProfile] = []
    @State private var isPresentingPetChooser = false
    @State private var newPetProfiles: [PetProfile] = []

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
                // recreating the whole trip.
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
                    ForEach(trip.travelers) { traveler in
                        HStack {
                            Text(traveler.name)
                            Spacer()
                            Button(role: .destructive) {
                                removeTraveler(traveler)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        newTravelerProfiles = []
                        isPresentingTravelerChooser = true
                    } label: {
                        Label("Add traveler", systemImage: "plus")
                    }
                } header: {
                    Text("Travelers")
                } footer: {
                    Text("Adding a traveler brings along their always-pack items. Removing one also removes their items from this trip.")
                }

                Section {
                    ForEach(trip.pets) { pet in
                        HStack {
                            Text(pet.name)
                            Spacer()
                            Button(role: .destructive) {
                                removePet(pet)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        newPetProfiles = []
                        isPresentingPetChooser = true
                    } label: {
                        Label("Add pet", systemImage: "plus")
                    }
                } header: {
                    Text("Pets")
                } footer: {
                    Text("Adding a pet brings along their always-pack items. Removing one also removes their items from this trip.")
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
            .sheet(isPresented: $isPresentingTravelerChooser, onDismiss: addNewTravelers) {
                TravelerChooserView(selectedProfiles: $newTravelerProfiles)
            }
            .sheet(isPresented: $isPresentingPetChooser, onDismiss: addNewPets) {
                PetChooserView(selectedProfiles: $newPetProfiles)
            }
        }
    }

    /// Turns whatever got picked in TravelerChooserView into real
    /// Traveler models on the trip, copying each profile's always-pack
    /// items along — the same thing AddTripView does at creation time.
    /// Doesn't also re-run PackingRulesEngine's age/activity/weather
    /// starter-list generation for the newcomer; that's a materially
    /// bigger step (a fresh forecast fetch, activity gear, etc.) than
    /// "add this person to the trip," so it's out of scope here.
    private func addNewTravelers() {
        guard !newTravelerProfiles.isEmpty else { return }
        let existingNames = Set(trip.travelers.map(\.name))
        for profile in newTravelerProfiles where !existingNames.contains(profile.name) {
            let traveler = Traveler(name: profile.name, ageBracket: profile.ageBracket, trip: trip)
            modelContext.insert(traveler)
            for profileItem in profile.alwaysItems {
                let item = PackingItem(
                    name: profileItem.name,
                    categoryName: profileItem.categoryName,
                    quantity: profileItem.quantity,
                    trip: trip,
                    traveler: traveler
                )
                modelContext.insert(item)
            }
        }
        newTravelerProfiles = []
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
            await TripSharingService.shared.resyncIfShared(trip)
        }
    }

    /// Same as addNewTravelers, for pets.
    private func addNewPets() {
        guard !newPetProfiles.isEmpty else { return }
        let existingNames = Set(trip.pets.map(\.name))
        for profile in newPetProfiles where !existingNames.contains(profile.name) {
            let pet = Pet(name: profile.name, species: profile.species, trip: trip)
            modelContext.insert(pet)
            for profileItem in profile.alwaysItems {
                let item = PackingItem(
                    name: profileItem.name,
                    categoryName: profileItem.categoryName,
                    quantity: profileItem.quantity,
                    trip: trip,
                    pet: pet
                )
                modelContext.insert(item)
            }
        }
        newPetProfiles = []
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
            await TripSharingService.shared.resyncIfShared(trip)
        }
    }

    /// Also deletes the traveler's own items from this trip's packing
    /// list, per explicit product decision — leaving them behind as
    /// unassigned "Shared" items would be a confusing pile nobody
    /// actually asked for once the person they belonged to is gone.
    private func removeTraveler(_ traveler: Traveler) {
        for item in trip.items where item.traveler?.id == traveler.id {
            modelContext.delete(item)
        }
        modelContext.delete(traveler)
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
            await TripSharingService.shared.resyncIfShared(trip)
        }
    }

    /// Same as removeTraveler, for pets.
    private func removePet(_ pet: Pet) {
        for item in trip.items where item.pet?.id == pet.id {
            modelContext.delete(item)
        }
        modelContext.delete(pet)
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
            await TripSharingService.shared.resyncIfShared(trip)
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
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
            ],
            inMemory: true
        )
}
