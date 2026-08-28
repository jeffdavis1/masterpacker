import SwiftUI
import SwiftData

struct NewProfileView: View {
    var onCreate: (TravelerProfile) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Traveler Profile")
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
        // ageBracket defaults to .adult (see TravelerProfile's init) — no
        // longer surfaced as a picker here; still used behind the scenes
        // by PackingRulesEngine's suggestion logic.
        let profile = TravelerProfile(name: name)
        modelContext.insert(profile)
        onCreate(profile)
        dismiss()
    }
}

#Preview {
    NewProfileView(onCreate: { _ in })
        .modelContainer(for: [TravelerProfile.self, PetProfile.self, ProfileItem.self], inMemory: true)
}
