import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    @Bindable var profile: TravelerProfile
    @Environment(\.modelContext) private var modelContext
    @Query private var allPackingItems: [PackingItem]
    @State private var isAddingCustomItem = false

    /// Suggestion chips tapped but not yet saved — tapping toggles the
    /// chip's color rather than immediately inserting into "Always Pack",
    /// so the list above doesn't jump around while browsing suggestions.
    /// Committed all at once via the Save button.
    @State private var pendingSuggestions: Set<CommonProfileItems.Suggestion> = []

    var body: some View {
        List {
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
                    ForEach(CommonProfileItems.grouped(curatedSuggestions), id: \.group) { bucket in
                        DisclosureGroup(bucket.group) {
                            SuggestionChipGrid(suggestions: bucket.suggestions, selected: pendingSuggestions, onToggle: togglePending)
                                .padding(.top, 4)
                        }
                        .listRowBackground(AppTheme.cardSurface)
                    }
                } header: {
                    Text("Common items")
                } footer: {
                    Text("Tap a category to see items, then tap to select, then Save.")
                }
            }

            if !frequentSuggestions.isEmpty {
                Section {
                    SuggestionChipGrid(suggestions: frequentSuggestions, selected: pendingSuggestions, onToggle: togglePending)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(pendingSuggestions.isEmpty ? "Save" : "Save (\(pendingSuggestions.count))") {
                    commitPending()
                }
                .disabled(pendingSuggestions.isEmpty)
            }
        }
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

    private func togglePending(_ suggestion: CommonProfileItems.Suggestion) {
        if pendingSuggestions.contains(suggestion) {
            pendingSuggestions.remove(suggestion)
        } else {
            pendingSuggestions.insert(suggestion)
        }
    }

    private func commitPending() {
        for suggestion in pendingSuggestions {
            let item = ProfileItem(name: suggestion.name, categoryName: suggestion.category.rawValue, profile: profile)
            modelContext.insert(item)
        }
        pendingSuggestions.removeAll()
    }

    private var existingNames: Set<String> {
        Set(profile.alwaysItems.map { $0.name.lowercased() })
    }

    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        CommonProfileItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    /// Item names *this traveler* has packed on 2+ distinct past trips,
    /// that aren't already saved to this profile or in the curated common
    /// list — scoped to them specifically so, say, traveler B's frequent
    /// coffee mug doesn't show up as a suggestion on traveler A's profile
    /// just because it's frequent app-wide.
    ///
    /// A trip's Traveler has no stored link back to the TravelerProfile it
    /// was created from (picking a profile just copies name/age bracket in
    /// as a one-time starting point — see TravelerProfile's own doc
    /// comment), so matching by name is the same proxy the rest of the
    /// app already uses for this (e.g. EditTripView's dedup check when
    /// adding travelers).
    private var frequentSuggestions: [CommonProfileItems.Suggestion] {
        let curatedNames = Set(CommonProfileItems.all.map { $0.name.lowercased() })

        var tripsByName: [String: (categoryName: String, trips: Set<PersistentIdentifier>)] = [:]
        for item in allPackingItems {
            guard let trip = item.trip else { continue }
            guard item.traveler?.name == profile.name else { continue }
            let key = item.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            tripsByName[key, default: (item.categoryName, [])].trips.insert(trip.persistentModelID)
        }

        // A frequent item logged under a custom trip category still needs
        // an actual PackingCategory for the suggestion chip it becomes
        // here (Suggestion doesn't carry free-form categories the way
        // ProfileItem/PackingItem do) — .misc is a reasonable landing spot
        // for that edge case rather than losing the suggestion entirely.
        return tripsByName
            .filter { $0.value.trips.count >= 2 }
            .filter { !existingNames.contains($0.key) && !curatedNames.contains($0.key) }
            .sorted { $0.value.trips.count > $1.value.trips.count }
            .prefix(8)
            .map {
                CommonProfileItems.Suggestion(
                    name: $0.key.capitalized,
                    category: PackingCategory(rawValue: $0.value.categoryName) ?? .misc
                )
            }
    }
}

/// Not private — reused by PetProfileDetailView (pet profiles) and
/// TemplateDetailView (My Bag), which show the same kind of suggestion
/// chips.
struct SuggestionChipGrid: View {
    let suggestions: [CommonProfileItems.Suggestion]
    let selected: Set<CommonProfileItems.Suggestion>
    let onToggle: (CommonProfileItems.Suggestion) -> Void

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                let isSelected = selected.contains(suggestion)
                Button {
                    onToggle(suggestion)
                } label: {
                    // The item's own icon normally, swapped for a
                    // checkmark once selected — surfaces the real icon
                    // library while still reading clearly as "selected"
                    // the same way the checkmark always did.
                    Label {
                        Text(suggestion.name)
                    } icon: {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            PackingIconView(icon: PackingIcon.iconRef(forName: suggestion.name, fallback: suggestion.category.symbol))
                        }
                    }
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? AppTheme.brand : AppTheme.brand.opacity(0.12))
                        .foregroundStyle(isSelected ? .white : AppTheme.brand)
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
        for: [TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self, Trip.self, Traveler.self, Pet.self, PackingItem.self, Luggage.self],
        inMemory: true
    )
}
