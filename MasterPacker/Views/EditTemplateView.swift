import SwiftUI
import SwiftData

/// Renames an existing bag. The only field a bag has is its name, so this
/// is deliberately just NewTemplateView's exact same form, pre-filled and
/// committing in place on Save instead of creating a new PackingTemplate —
/// same "new and edit show the same fields" split EditTripView/AddTripView
/// already use.
struct EditTemplateView: View {
    @Bindable var template: PackingTemplate
    @Environment(\.dismiss) private var dismiss

    @State private var name: String

    init(template: PackingTemplate) {
        self.template = template
        _name = State(initialValue: template.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Bag name (e.g. \"Camping Essentials\")", text: $name)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Edit Bag")
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
        }
    }

    private func save() {
        template.name = name
        dismiss()
    }
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return EditTemplateView(template: template)
        .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
