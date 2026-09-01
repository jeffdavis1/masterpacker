import SwiftUI
import SwiftData

struct AddTemplateItemView: View {
    let template: PackingTemplate
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var name = ""
    @State private var categoryName = PackingCategory.misc.rawValue
    @State private var quantity = 1
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
        let item = TemplateItem(name: name, categoryName: categoryName, quantity: quantity, template: template)
        modelContext.insert(item)
        dismiss()
    }
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return AddTemplateItemView(template: template)
        .modelContainer(for: [PackingTemplate.self, TemplateItem.self, CustomCategory.self], inMemory: true)
}
