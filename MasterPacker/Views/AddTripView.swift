import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelerProfile.name) private var savedProfiles: [TravelerProfile]

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 3)
    @State private var travelMethod: TravelMethod = .car
    @State private var selectedActivities: Set<Activity> = []
    @State private var notes = ""
    @State private var selectedProfiles: [TravelerProfile] = []
    @State private var pets: [PetDraft] = []
    @State private var generateSuggestions = true
    @State private var isPresentingTravelerChooser = false
    @State private var isPresentingNewProfile = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(selectedProfiles) { profile in
                        HStack {
                            Text(profile.name)
                            Spacer()
                            Button(role: .destructive) {
                                selectedProfiles.removeAll { $0.id == profile.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        isPresentingTravelerChooser = true
                    } label: {
                        Label("Add traveler", systemImage: "plus")
                    }
                } header: {
                    Text("Travelers")
                } footer: {
                    Text("Their always-pack items come along automatically.")
                }

                Section("Trip") {
                    TextField("Trip name", text: $name)
                    TextField("Destination", text: $destination)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                    Picker("Travel method", selection: $travelMethod) {
                        ForEach(TravelMethod.allCases) { method in
                            Label(method.rawValue, systemImage: method.symbol).tag(method)
                        }
                    }
                }

                Section("Activities") {
                    ActivityChipGrid(selected: $selectedActivities)
                    TextField("Notes (e.g. \"visiting grandma\")", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Pets") {
                    ForEach($pets) { $pet in
                        PetRow(draft: $pet) {
                            pets.removeAll { $0.id == pet.id }
                        }
                    }
                    Button {
                        pets.append(PetDraft(name: "", species: .dog))
                    } label: {
                        Label("Add pet", systemImage: "plus")
                    }
                }

                Section {
                    Toggle("Generate suggested packing list", isOn: $generateSuggestions)
                } footer: {
                    Text("Adds a starter checklist based on travelers, activities, and trip length. You can edit it afterward.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Add Traveler", isPresented: $isPresentingTravelerChooser, titleVisibility: .visible) {
                ForEach(availableProfiles) { profile in
                    Button(profile.name) {
                        selectedProfiles.append(profile)
                    }
                }
                Button("Create New Traveler") {
                    isPresentingNewProfile = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $isPresentingNewProfile) {
                NewProfileView { profile in
                    selectedProfiles.append(profile)
                }
            }
        }
    }

    private var availableProfiles: [TravelerProfile] {
        savedProfiles.filter { profile in !selectedProfiles.contains { $0.id == profile.id } }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedProfiles.isEmpty
    }

    private func save() {
        let trip = Trip(
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            travelMethod: travelMethod,
            activities: selectedActivities,
            notes: notes
        )
        modelContext.insert(trip)

        let travelerModels = selectedProfiles.map { profile -> Traveler in
            let traveler = Traveler(name: profile.name, ageBracket: profile.ageBracket, trip: trip)
            modelContext.insert(traveler)
            return traveler
        }

        let petModels = pets
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { draft -> Pet in
                let pet = Pet(name: draft.name, species: draft.species, trip: trip)
                modelContext.insert(pet)
                return pet
            }

        trip.travelers = travelerModels
        trip.pets = petModels

        if generateSuggestions {
            for generated in PackingRulesEngine.generate(for: trip) {
                let traveler: Traveler?
                let pet: Pet?
                switch generated.assignee {
                case .shared:
                    traveler = nil
                    pet = nil
                case .traveler(let t):
                    traveler = t
                    pet = nil
                case .pet(let p):
                    traveler = nil
                    pet = p
                }
                let item = PackingItem(
                    name: generated.name,
                    category: generated.category,
                    quantity: generated.quantity,
                    trip: trip,
                    traveler: traveler,
                    pet: pet
                )
                modelContext.insert(item)
            }
        }

        // Always-pack items from each traveler's saved profile aren't gated
        // by the "generate suggested packing list" toggle above — the
        // whole point of saving them is that you always want them.
        for (profile, traveler) in zip(selectedProfiles, travelerModels) {
            for profileItem in profile.alwaysItems {
                // Profile items can use a custom category (text-only, no
                // matching PackingCategory case); fall back to .misc for
                // the actual trip item in that case.
                let item = PackingItem(
                    name: profileItem.name,
                    category: PackingCategory(rawValue: profileItem.categoryName) ?? .misc,
                    quantity: profileItem.quantity,
                    trip: trip,
                    traveler: traveler
                )
                modelContext.insert(item)
            }
        }

        dismiss()
    }
}

private struct PetDraft: Identifiable {
    let id = UUID()
    var name: String
    var species: PetSpecies
}

private struct PetRow: View {
    @Binding var draft: PetDraft
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Pet name", text: $draft.name)
            Picker("", selection: $draft.species) {
                ForEach(PetSpecies.allCases) { species in
                    Label(species.rawValue, systemImage: species.symbol).tag(species)
                }
            }
            .labelsHidden()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ActivityChipGrid: View {
    @Binding var selected: Set<Activity>

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Activity.allCases) { activity in
                let isSelected = selected.contains(activity)
                Button {
                    if isSelected {
                        selected.remove(activity)
                    } else {
                        selected.insert(activity)
                    }
                } label: {
                    Label(activity.rawValue, systemImage: activity.symbol)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddTripView()
        .modelContainer(
            for: [Trip.self, PackingItem.self, Traveler.self, Pet.self, TravelerProfile.self, ProfileItem.self, CustomCategory.self],
            inMemory: true
        )
}
