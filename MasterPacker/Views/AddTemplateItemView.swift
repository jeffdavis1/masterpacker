import SwiftUI
import SwiftData

struct AddTemplateItemView: View {
    let template: PackingTemplate
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
        let item = TemplateItem(name: name, category: category, quantity: quantity, template: template)
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return AddTemplateItemView(template: template)
        .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
