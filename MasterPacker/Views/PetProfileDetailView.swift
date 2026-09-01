import SwiftUI
import SwiftData

/// Mirrors ProfileDetailView, but for a saved pet — same pending-selection
/// suggestion chips + Save flow, curated common items, and "you often pack
/// these" learned from past trips (scoped to items actually assigned to a
/// pet, unlike the traveler version which looks at all trip items).
struct PetProfileDetailView: View {
    @Bindable var profile: PetProfile
    @Environment(\.modelContext) private var modelContext
    @Query private var allPackingItems: [PackingItem]
    @State private var isAddingCustomItem = false
    @State private var pendingSuggestions: Set<CommonProfileItems.Suggestion> = []

    var body: some View {
        List {
            Section {
                Picker("Species", selection: $profile.species) {
                    ForEach(PetSpecies.allCases) { species in
                        Label(species.rawValue, systemImage: species.symbol).tag(species)
                    }
                }
            }
            .listRowBackground(AppTheme.cardSurface)

            Section {
                if profile.alwaysItems.isEmpty {
                    Text("No always-pack items yet — add some below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(profile.alwaysItems) { item in
                        HStack {
                            PackingIconView(icon: item.displaySymbol)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(item.name)
                            if item.quantity > 1 {
                                Spacer()
                                Text("×\(item.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(AppTheme.cardSurface)
                    }
                    .onDelete(perform: deleteItems)
                }

                Button {
                    isAddingCustomItem = true
                } label: {
                    Label("Add custom item", systemImage: "plus")
                }
                .listRowBackground(AppTheme.cardSurface)
            } header: {
                Text("Always Pack")
            }

            if !curatedSuggestions.isEmpty {
                Section {
                    SuggestionChipGrid(suggestions: curatedSuggestions, selected: pendingSuggestions, onToggle: togglePending)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Common items")
                } footer: {
                    Text("Tap to select, then Save.")
                }
            }

            if !frequentSuggestions.isEmpty {
                Section {
                    SuggestionChipGrid(suggestions: frequentSuggestions, selected: pendingSuggestions, onToggle: togglePending)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("You often pack these")
                } footer: {
                    Text("Pet items you've added on 2 or more past trips, not already in your common list.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(pendingSuggestions.isEmpty ? "Save" : "Save (\(pendingSuggestions.count))") {
                    commitPending()
                }
                .disabled(pendingSuggestions.isEmpty)
            }
        }
        .sheet(isPresented: $isAddingCustomItem) {
            AddProfileItemView(petProfile: profile)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = profile.alwaysItems
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func togglePending(_ suggestion: CommonProfileItems.Suggestion) {
        if pendingSuggestions.contains(suggestion) {
            pendingSuggestions.remove(suggestion)
        } else {
            pendingSuggestions.insert(suggestion)
        }
    }

    private func commitPending() {
        for suggestion in pendingSuggestions {
            let item = ProfileItem(name: suggestion.name, categoryName: suggestion.category.rawValue, petProfile: profile)
            modelContext.insert(item)
        }
        pendingSuggestions.removeAll()
    }

    private var existingNames: Set<String> {
        Set(profile.alwaysItems.map { $0.name.lowercased() })
    }

    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        CommonPetItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    private var frequentSuggestions: [CommonProfileItems.Suggestion] {
        let curatedNames = Set(CommonPetItems.all.map { $0.name.lowercased() })

        var tripsByName: [String: (category: PackingCategory, trips: Set<PersistentIdentifier>)] = [:]
        for item in allPackingItems {
            guard item.pet != nil, let trip = item.trip else { continue }
            let key = item.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            tripsByName[key, default: (item.category, [])].trips.insert(trip.persistentModelID)
        }

        return tripsByName
            .filter { $0.value.trips.count >= 2 }
            .filter { !existingNames.contains($0.key) && !curatedNames.contains($0.key) }
            .sorted { $0.value.trips.count > $1.value.trips.count }
            .prefix(8)
            .map { CommonProfileItems.Suggestion(name: $0.key.capitalized, category: $0.value.category) }
    }
}

#Preview {
    let profile = PetProfile(name: "Preview Pup")
    return NavigationStack {
        PetProfileDetailView(profile: profile)
    }
    .modelContainer(
        for: [PetProfile.self, TravelerProfile.self, ProfileItem.self, CustomCategory.self, Trip.self, Traveler.self, Pet.self, PackingItem.self, Luggage.self],
        inMemory: true
    )
}
