import SwiftUI
import SwiftData

struct NewTemplateView: View {
    var onCreate: (PackingTemplate) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Template name (e.g. \"Camping Essentials\")", text: $name)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Template")
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
        let template = PackingTemplate(name: name)
        modelContext.insert(template)
        onCreate(template)
        dismiss()
    }
}

#Preview {
    NewTemplateView(onCreate: { _ in })
        .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
