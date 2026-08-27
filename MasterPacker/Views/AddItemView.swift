import SwiftUI
import SwiftData

struct AddItemView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: PackingCategory = .misc
    @State private var quantity = 1
    @State private var assignee: AssigneeOption = .shared

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(PackingCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.symbol).tag(category)
                    }
                }
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...20)
                Picker("Assign to", selection: $assignee) {
                    Text("Shared / Household").tag(AssigneeOption.shared)
                    ForEach(trip.travelers) { traveler in
                        Text(traveler.name).tag(AssigneeOption.traveler(traveler))
                    }
                    ForEach(trip.pets) { pet in
                        Text("\(pet.name) (pet)").tag(AssigneeOption.pet(pet))
                    }
                }
            }
            .navigationTitle("New Item")
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
        let traveler: Traveler?
        let pet: Pet?
        switch assignee {
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

        let item = PackingItem(name: name, category: category, quantity: quantity, trip: trip, traveler: traveler, pet: pet)
        modelContext.insert(item)
        dismiss()
    }
}

enum AssigneeOption: Hashable {
    case shared
    case traveler(Traveler)
    case pet(Pet)
}

#Preview {
    let trip = Trip(name: "Preview Trip", destination: "Somewhere", startDate: .now, endDate: .now)
    return AddItemView(trip: trip)
        .modelContainer(for: [Trip.self, PackingItem.self, Traveler.self, Pet.self], inMemory: true)
}
