import SwiftUI
import SwiftData

struct AddItemView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: PackingCategory = .misc
    @State private var quantity = 1

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
        let item = PackingItem(name: name, category: category, quantity: quantity, trip: trip)
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    let trip = Trip(name: "Preview Trip", destination: "Somewhere", startDate: .now, endDate: .now)
    return AddItemView(trip: trip)
        .modelContainer(for: [Trip.self, PackingItem.self], inMemory: true)
}
