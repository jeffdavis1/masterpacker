import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Bindable var template: PackingTemplate
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingItem = false

    /// Suggestion chips tapped but not yet saved — tapping toggles the
    /// chip's color rather than immediately inserting into the bag, so
    /// the grid doesn't reflow (and the item the user was about to tap
    /// next doesn't shift) while browsing suggestions. Committed all at
    /// once via the Save button — same pattern as ProfileDetailView's
    /// Always Pack chips.
    @State private var pendingSuggestions: Set<CommonProfileItems.Suggestion> = []

    var body: some View {
        List {
            if template.items.isEmpty {
                Text("No items yet — browse suggestions below, or tap + to add one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                // Grouped the same way TripDetailView groups a trip's own
                // items — built-in categories only here; a custom one is
                // deliberately NOT included (see customGroups below).
                ForEach(groupedItems.builtIn) { group in
                    Section {
                        ForEach(group.items) { item in
                            HStack {
                                PackingIconView(icon: item.displaySymbol)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(item.name)
                                Spacer()
                                if item.quantity > 1 {
                                    Text("×\(item.quantity)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                // A dedicated trash target — tapping
                                // anywhere else on the row does nothing,
                                // so browsing the list can't accidentally
                                // remove an item the way a whole-row tap
                                // did.
                                Button {
                                    modelContext.delete(item)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                            .listRowBackground(AppTheme.cardSurface)
                        }
                        .onDelete { offsets in deleteItems(in: group, at: offsets) }
                    } header: {
                        Label(group.label, systemImage: group.symbol)
                    }
                }
            }

            if !curatedSuggestions.isEmpty || !groupedItems.custom.isEmpty {
                Section {
                    ForEach(CommonProfileItems.grouped(curatedSuggestions), id: \.group) { bucket in
                        DisclosureGroup(bucket.group) {
                            SuggestionChipGrid(suggestions: bucket.suggestions, selected: pendingSuggestions, onToggle: togglePending)
                                .padding(.top, 4)
                        }
                        .listRowBackground(AppTheme.cardSurface)
                    }
                    // A custom category reads as "one of the regular
                    // categories" living down here alongside the built-in
                    // ones, per explicit design decision — same collapsed-
                    // by-default DisclosureGroup, just showing the items
                    // already filed there (still deletable) instead of
                    // curated suggestions to add, since there's nothing
                    // curated for a name the user just typed in.
                    ForEach(groupedItems.custom) { group in
                        DisclosureGroup(group.label) {
                            ForEach(group.items) { item in
                                HStack {
                                    PackingIconView(icon: item.displaySymbol)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Text(item.name)
                                    Spacer()
                                    if item.quantity > 1 {
                                        Text("×\(item.quantity)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Button {
                                        modelContext.delete(item)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)
                                }
                            }
                            .onDelete { offsets in deleteItems(in: group, at: offsets) }
                            .padding(.top, 4)
                        }
                        .listRowBackground(AppTheme.cardSurface)
                    }
                } header: {
                    Text("Suggested items")
                } footer: {
                    Text("Tap a category to see items, then tap to select, then Save.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Renaming the bag moved to a swipe action on TemplateListView's
            // row — that freed this leading slot, so Add now gets top
            // billing instead of hiding as a list row underneath the
            // (usually longer) built-in item sections.
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isAddingItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                Button(pendingSuggestions.isEmpty ? "Save" : "Save (\(pendingSuggestions.count))") {
                    commitPendingSuggestions()
                }
                .disabled(pendingSuggestions.isEmpty)
            }
        }
        .sheet(isPresented: $isAddingItem) {
            AddTemplateItemView(template: template)
        }
    }

    private func deleteItems(in group: CategoryGroup, at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(group.items[index])
        }
    }

    /// One category's items within the bag — same label/symbol/custom-
    /// category approach as TripDetailView's own displayGroups(for:),
    /// applied to TemplateItem instead of PackingItem.
    private struct CategoryGroup: Identifiable {
        var id: String { label }
        let label: String
        let symbol: String
        let items: [TemplateItem]
    }

    /// Split rather than one combined list — builtIn renders as its own
    /// top-of-page sections, custom renders down alongside "Suggested
    /// items" instead (see body). Computed together since both need the
    /// same underlying grouping pass.
    private var groupedItems: (builtIn: [CategoryGroup], custom: [CategoryGroup]) {
        let grouped = Dictionary(grouping: template.items) { item in
            ItemDisplayGroup.group(forName: item.name, categoryName: item.categoryName)
        }
        let builtIn = CommonProfileItems.groupOrder.compactMap { group -> CategoryGroup? in
            guard let groupItems = grouped[group], !groupItems.isEmpty else { return nil }
            return CategoryGroup(
                label: group,
                symbol: ItemDisplayGroup.symbol(for: group),
                items: groupItems.sorted { $0.name < $1.name }
            )
        }
        let fixedGroupNames = Set(CommonProfileItems.groupOrder)
        let custom = grouped.keys
            .filter { !fixedGroupNames.contains($0) }
            .sorted()
            .map { group in
                CategoryGroup(
                    label: group,
                    symbol: ItemDisplayGroup.symbol(for: group),
                    items: grouped[group]!.sorted { $0.name < $1.name }
                )
            }
        return (builtIn, custom)
    }

    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        let existingNames = Set(template.items.map { $0.name.lowercased() })
        return CommonProfileItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    private func togglePending(_ suggestion: CommonProfileItems.Suggestion) {
        if pendingSuggestions.contains(suggestion) {
            pendingSuggestions.remove(suggestion)
        } else {
            pendingSuggestions.insert(suggestion)
        }
    }

    private func commitPendingSuggestions() {
        for suggestion in pendingSuggestions {
            let item = TemplateItem(name: suggestion.name, categoryName: suggestion.category.rawValue, template: template)
            modelContext.insert(item)
        }
        pendingSuggestions.removeAll()
    }
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return NavigationStack {
        TemplateDetailView(template: template)
    }
    .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
