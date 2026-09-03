import SwiftUI
import SwiftData

struct NewPetProfileView: View {
    var onCreate: (PetProfile) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var species: PetSpecies = .dog

    var body: some View {
        NavigationStack {
            Form {
                TextField("Pet name", text: $name)
                Picker("Species", selection: $species) {
                    ForEach(PetSpecies.allCases) { species in
                        Label(species.rawValue, systemImage: species.symbol).tag(species)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Pet Profile")
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
        let profile = PetProfile(name: name, species: species)
        modelContext.insert(profile)
        AnalyticsService.petProfileCreated()
        onCreate(profile)
        dismiss()
    }
}

#Preview {
    NewPetProfileView(onCreate: { _ in })
        .modelContainer(for: [PetProfile.self, TravelerProfile.self, ProfileItem.self], inMemory: true)
}
