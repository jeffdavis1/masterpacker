import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Bindable var template: PackingTemplate
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TravelerProfile.name) private var travelerProfiles: [TravelerProfile]
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
            // Always its own Section — even while the bag is empty — so
            // adding the first item never makes a brand-new section
            // spring into existence above "Suggested items" and shove it
            // (and wherever the user was scrolled/tapping) down the
            // page. Only the row content inside swaps between the empty
            // placeholder and the real category groups; the section
            // boundary itself never appears or disappears.
            Section {
                if template.items.isEmpty {
                    Text("No items yet — browse suggestions below, or tap + to add one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    // Every category the bag actually has items in —
                    // built-in ones first in their usual order, then any
                    // custom ones alphabetically — each collapsed behind
                    // its own DisclosureGroup with a count, so the page
                    // reads as two clear chunks: what's already in the
                    // bag, and what's just being suggested (below).
                    ForEach(allItemGroups) { group in
                        DisclosureGroup {
                            ForEach(group.items) { item in
                                TemplateItemRow(item: item) {
                                    modelContext.delete(item)
                                }
                            }
                            .onDelete { offsets in deleteItems(in: group, at: offsets) }
                            .padding(.top, 4)
                        } label: {
                            HStack {
                                Label(group.label, systemImage: group.symbol)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(AppTheme.cardSurface)
                    }
                }
            } header: {
                Text("My Items")
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
                    Text("Suggested items")
                } footer: {
                    Text("Tap a category to see items, then tap to select, then Save.")
                }
            }

            if !travelerProfiles.isEmpty {
                Section {
                    OwnerChipGrid(profiles: travelerProfiles, owner: $template.owner)
                        .listRowBackground(AppTheme.cardSurface)
                } header: {
                    Text("Owner")
                } footer: {
                    Text("Leave unassigned to offer this bag on every trip. Assign it to one traveler to only offer it when they're on the trip.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Renaming the bag moved to a swipe action on TemplateListView's
            // row — that freed this leading slot, so Add now gets top
            // billing instead of hiding as a list row underneath the
            // (usually longer) built-in item sections.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add Item")
            }
            // Two adjacent ToolbarItems still fuse into one glass pill
            // under the Liquid Glass toolbar style — a plain second
            // ToolbarItem isn't enough to split them, this spacer is the
            // actual break between the two capsules.
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItem(placement: .primaryAction) {
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
        AnalyticsService.bagItemsDeleted(count: offsets.count)
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

    /// Every category the bag has items in, built-in ones first in their
    /// usual order, then any custom ones alphabetically after — a single
    /// list since "My Items" now renders both the same way (a collapsed
    /// DisclosureGroup with a count), unlike the old split where custom
    /// categories rendered down in "Suggested items" instead.
    private var allItemGroups: [CategoryGroup] {
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
                    items: (grouped[group] ?? []).sorted { $0.name < $1.name }
                )
            }
        return builtIn + custom
    }

    /// The bag's name with an item count appended once it has any, e.g.
    /// "Golf (6)" — tapping Save disables the button (nothing pending
    /// left to save), which reads as "did that actually work?" with no
    /// other feedback since the screen otherwise looks unchanged until
    /// you back out. The count updating right there in the title is
    /// confirmation the save landed without needing a toast or a
    /// separate "Saved" state to manage.
    private var navigationTitle: String {
        template.items.isEmpty ? template.name : "\(template.name) (\(template.items.count))"
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
        AnalyticsService.bagSuggestionsCommitted(count: pendingSuggestions.count)
        for suggestion in pendingSuggestions {
            let item = TemplateItem(name: suggestion.name, categoryName: suggestion.category.rawValue, template: template)
            modelContext.insert(item)
        }
        pendingSuggestions.removeAll()
    }
}

/// Tap-to-select chips for assigning this bag's single owner — same
/// capsule style as ActivityChipGrid/SuggestionChipGrid. Single-use, so
/// it lives here rather than as its own file. A bag belongs to at most
/// one traveler: tapping a different chip replaces the current owner,
/// tapping the current owner again clears it back to unassigned.
private struct OwnerChipGrid: View {
    let profiles: [TravelerProfile]
    @Binding var owner: TravelerProfile?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(profiles) { profile in
                let isOwner = owner?.id == profile.id
                Button {
                    owner = isOwner ? nil : profile
                    AnalyticsService.bagOwnerChanged(isNowOwned: !isOwner)
                } label: {
                    Text(profile.name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isOwner ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isOwner ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

/// One item's row within a bag's "My Items" list. Tapping the row (the
/// trash button is a separate, dedicated target) opens a category
/// picker — items land in a category at add time (AddTemplateItemView)
/// with no way to change it afterward otherwise, which is exactly what
/// surfaced the Gear-category display bug: nothing to fix a
/// miscategorized item except delete and re-add it.
private struct TemplateItemRow: View {
    @Bindable var item: TemplateItem
    let onDelete: () -> Void
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]
    @State private var isEditingCategory = false

    var body: some View {
        HStack {
            // Everything but the trash button is one tappable region —
            // grouped so the ×N badge (plain text here, not its own
            // button the way TripDetailView's quantity editor is) opens
            // the same category picker as tapping the icon or name.
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
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isEditingCategory = true
            }
            .popover(isPresented: $isEditingCategory) {
                VStack(spacing: 12) {
                    Text(item.name)
                        .font(.headline)
                    Picker("Category", selection: $item.categoryName) {
                        ForEach(PackingCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.symbol).tag(category.rawValue)
                        }
                        ForEach(customCategories) { custom in
                            Label(custom.name, systemImage: "tag").tag(custom.name)
                        }
                    }
                }
                .padding()
                .presentationCompactAdaptation(.popover)
            }

            // A dedicated trash target — kept as its own HStack sibling
            // (reserving its own space) rather than layered over the
            // row, so it can't visually collide with the ×N badge.
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Delete \(item.name)")
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
    }
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return NavigationStack {
        TemplateDetailView(template: template)
    }
    .modelContainer(
        for: [PackingTemplate.self, TemplateItem.self, TravelerProfile.self, ProfileItem.self],
        inMemory: true
    )
}
