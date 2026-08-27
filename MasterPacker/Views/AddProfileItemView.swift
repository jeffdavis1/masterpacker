import SwiftUI
import SwiftData

struct AddProfileItemView: View {
    let profile: TravelerProfile
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
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Always-Pack Item")
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
        let item = ProfileItem(name: name, category: category, quantity: quantity, profile: profile)
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    let profile = TravelerProfile(name: "Preview")
    return AddProfileItemView(profile: profile)
        .modelContainer(for: [TravelerProfile.self, ProfileItem.self], inMemory: true)
}
