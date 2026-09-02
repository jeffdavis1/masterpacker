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
                TextField("Bag name (e.g. \"Camping Essentials\")", text: $name)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Bag")
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
        AnalyticsService.bagCreated()
        // Permanently retires the My Bag onboarding coach mark — this is
        // the exact moment the feature it's pointing at gets used for
        // the first time.
        CoachMarkStore.recordFirstBagCreated()
        onCreate(template)
        dismiss()
    }
}

#Preview {
    NewTemplateView(onCreate: { _ in })
        .modelContainer(
            for: [PackingTemplate.self, TemplateItem.self, TravelerProfile.self, ProfileItem.self],
            inMemory: true
        )
}
