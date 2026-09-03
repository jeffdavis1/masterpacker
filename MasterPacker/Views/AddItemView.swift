import SwiftUI
import SwiftData

struct AddItemView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var name = ""
    @State private var categoryName = PackingCategory.misc.rawValue
    @State private var quantity = 1
    @State private var assignee: AssigneeOption = .shared
    @State private var isAddingCustomCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name)
                Picker("Category", selection: $categoryName) {
                    ForEach(PackingCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.symbol).tag(category.rawValue)
                    }
                    ForEach(customCategories) { custom in
                        Label(custom.name, systemImage: "tag").tag(custom.name)
                    }
                }
                Button {
                    isAddingCustomCategory = true
                } label: {
                    Label("Add custom category", systemImage: "plus")
                }
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...20)
                Picker("Assign to", selection: $assignee) {
                    Text("Everyone").tag(AssigneeOption.shared)
                    ForEach(trip.travelers) { traveler in
                        Text(traveler.name).tag(AssigneeOption.traveler(traveler))
                    }
                    ForEach(trip.pets) { pet in
                        Text("\(pet.name) (pet)").tag(AssigneeOption.pet(pet))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
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
            .alert("New Category", isPresented: $isAddingCustomCategory) {
                TextField("Category name", text: $newCategoryName)
                Button("Cancel", role: .cancel) { newCategoryName = "" }
                Button("Add") { addCustomCategory() }
            } message: {
                Text("Saved categories can be reused for future items.")
            }
        }
    }

    private func addCustomCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        newCategoryName = ""
        guard !trimmed.isEmpty else { return }

        let existingNames = Set(
            PackingCategory.allCases.map { $0.rawValue.lowercased() } + customCategories.map { $0.name.lowercased() }
        )
        if !existingNames.contains(trimmed.lowercased()) {
            modelContext.insert(CustomCategory(name: trimmed))
            AnalyticsService.customCategoryCreated()
        }
        categoryName = trimmed
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

        let item = PackingItem(name: name, categoryName: categoryName, quantity: quantity, trip: trip, traveler: traveler, pet: pet)
        modelContext.insert(item)
        Task { await TripSharingService.shared.resyncIfShared(trip) }
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
        .modelContainer(for: [Trip.self, PackingItem.self, Luggage.self, Traveler.self, Pet.self, CustomCategory.self], inMemory: true)
}
