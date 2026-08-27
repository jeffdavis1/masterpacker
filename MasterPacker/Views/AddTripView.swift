import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 3)
    @State private var travelMethod: TravelMethod = .car
    @State private var selectedActivities: Set<Activity> = []
    @State private var notes = ""
    @State private var travelers: [TravelerDraft] = [TravelerDraft(name: "Me", ageBracket: .adult)]
    @State private var pets: [PetDraft] = []
    @State private var generateSuggestions = true

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Travelers") {
                    ForEach($travelers) { $traveler in
                        TravelerRow(draft: $traveler) {
                            travelers.removeAll { $0.id == traveler.id }
                        }
                    }
                    Button {
                        travelers.append(TravelerDraft(name: "", ageBracket: .adult))
                    } label: {
                        Label("Add traveler", systemImage: "plus")
                    }
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
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
            travelers.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
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

        let travelerModels = travelers
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { draft -> Traveler in
                let traveler = Traveler(name: draft.name, ageBracket: draft.ageBracket, trip: trip)
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

        dismiss()
    }
}

private struct TravelerDraft: Identifiable {
    let id = UUID()
    var name: String
    var ageBracket: AgeBracket
}

private struct PetDraft: Identifiable {
    let id = UUID()
    var name: String
    var species: PetSpecies
}

private struct TravelerRow: View {
    @Binding var draft: TravelerDraft
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Name", text: $draft.name)
            Picker("", selection: $draft.ageBracket) {
                ForEach(AgeBracket.allCases) { bracket in
                    Text(bracket.rawValue).tag(bracket)
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
        .modelContainer(for: [Trip.self, PackingItem.self, Traveler.self, Pet.self], inMemory: true)
}
