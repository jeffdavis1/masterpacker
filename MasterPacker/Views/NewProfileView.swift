import SwiftUI
import SwiftData

struct NewProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ageBracket: AgeBracket = .adult

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Age bracket", selection: $ageBracket) {
                    ForEach(AgeBracket.allCases) { bracket in
                        Text(bracket.rawValue).tag(bracket)
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
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let profile = TravelerProfile(name: name, ageBracket: ageBracket)
        modelContext.insert(profile)
        dismiss()
    }
}

#Preview {
    NewProfileView()
        .modelContainer(for: [TravelerProfile.self, ProfileItem.self], inMemory: true)
}
