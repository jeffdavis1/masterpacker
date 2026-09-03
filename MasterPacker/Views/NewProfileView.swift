import SwiftUI
import SwiftData

struct NewProfileView: View {
    var onCreate: (TravelerProfile) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelerProfile.name) private var existingProfiles: [TravelerProfile]

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                } footer: {
                    // Matches "you're always packing for the same people"
                    // reality this whole screen exists for — a second
                    // "Jeff" would also be indistinguishable to the
                    // per-traveler frequent-item suggestions, which match
                    // trip travelers back to a profile by name.
                    if isDuplicateName {
                        Text("You already have a traveler saved with this name.")
                            .foregroundStyle(.red)
                    }
                }
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
                        .disabled(!isValid)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicateName: Bool {
        let trimmed = trimmedName
        guard !trimmed.isEmpty else { return false }
        return existingProfiles.contains { $0.name.lowercased() == trimmed.lowercased() }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    private func save() {
        // ageBracket defaults to .adult (see TravelerProfile's init) — no
        // longer surfaced as a picker here; still used behind the scenes
        // by PackingRulesEngine's suggestion logic.
        let profile = TravelerProfile(name: trimmedName)
        modelContext.insert(profile)
        AnalyticsService.travelerProfileCreated()
        onCreate(profile)
        dismiss()
    }
}

#Preview {
    NewProfileView(onCreate: { _ in })
        .modelContainer(for: [TravelerProfile.self, PetProfile.self, ProfileItem.self], inMemory: true)
}
