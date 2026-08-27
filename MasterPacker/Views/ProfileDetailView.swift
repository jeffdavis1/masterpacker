import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    @Bindable var profile: TravelerProfile
    @Environment(\.modelContext) private var modelContext
    @Query private var allPackingItems: [PackingItem]
    @State private var isAddingCustomItem = false

    var body: some View {
        List {
            Section {
                Picker("Age bracket", selection: $profile.ageBracket) {
                    ForEach(AgeBracket.allCases) { bracket in
                        Text(bracket.rawValue).tag(bracket)
                    }
                }
            }
            .listRowBackground(Color.white)

            Section {
                if profile.alwaysItems.isEmpty {
                    Text("No always-pack items yet — add some below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(profile.alwaysItems) { item in
                        HStack {
                            Image(systemName: item.category.symbol)
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
                        .listRowBackground(Color.white)
                    }
                    .onDelete(perform: deleteItems)
                }

                Button {
                    isAddingCustomItem = true
                } label: {
                    Label("Add custom item", systemImage: "plus")
                }
                .listRowBackground(Color.white)
            } header: {
                Text("Always Pack")
            }

            if !curatedSuggestions.isEmpty {
                Section {
                    SuggestionChipGrid(suggestions: curatedSuggestions, onTap: addSuggestion)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Common items")
                }
            }

            if !frequentSuggestions.isEmpty {
                Section {
                    SuggestionChipGrid(suggestions: frequentSuggestions, onTap: addSuggestion)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("You often pack these")
                } footer: {
                    Text("Items you've added on 2 or more past trips, not already in your common list.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingCustomItem) {
            AddProfileItemView(profile: profile)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = profile.alwaysItems
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func addSuggestion(_ suggestion: CommonProfileItems.Suggestion) {
        let item = ProfileItem(name: suggestion.name, category: suggestion.category, profile: profile)
        modelContext.insert(item)
    }

    private var existingNames: Set<String> {
        Set(profile.alwaysItems.map { $0.name.lowercased() })
    }

    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        CommonProfileItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    /// Item names the user has packed on 2+ distinct past trips, that
    /// aren't already saved to this profile or in the curated common list.
    private var frequentSuggestions: [CommonProfileItems.Suggestion] {
        let curatedNames = Set(CommonProfileItems.all.map { $0.name.lowercased() })

        var tripsByName: [String: (category: PackingCategory, trips: Set<PersistentIdentifier>)] = [:]
        for item in allPackingItems {
            guard let trip = item.trip else { continue }
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

private struct SuggestionChipGrid: View {
    let suggestions: [CommonProfileItems.Suggestion]
    let onTap: (CommonProfileItems.Suggestion) -> Void

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    Label(suggestion.name, systemImage: "plus.circle.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.brand.opacity(0.12))
                        .foregroundStyle(AppTheme.brand)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let profile = TravelerProfile(name: "Preview")
    return NavigationStack {
        ProfileDetailView(profile: profile)
    }
    .modelContainer(
        for: [TravelerProfile.self, ProfileItem.self, Trip.self, Traveler.self, Pet.self, PackingItem.self],
        inMemory: true
    )
}
