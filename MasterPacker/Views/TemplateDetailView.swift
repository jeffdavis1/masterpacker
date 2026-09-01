import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Bindable var template: PackingTemplate
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingItem = false

    var body: some View {
        List {
            if template.items.isEmpty {
                Text("No items yet — add some below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                // Grouped the same way TripDetailView groups a trip's own
                // items — a custom category gets its own labeled section
                // here too, rather than sitting undifferentiated in one
                // flat pile alongside everything else.
                ForEach(displayGroups) { group in
                    Section {
                        ForEach(group.items) { item in
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
                        .onDelete { offsets in deleteItems(in: group, at: offsets) }
                    } header: {
                        Label(group.label, systemImage: group.symbol)
                    }
                }
            }

            Button {
                isAddingItem = true
            } label: {
                Label("Add item", systemImage: "plus")
            }
            .listRowBackground(AppTheme.cardSurface)

            if !curatedSuggestions.isEmpty {
                Section {
                    ForEach(CommonProfileItems.grouped(curatedSuggestions), id: \.group) { bucket in
                        DisclosureGroup(bucket.group) {
                            SuggestionChipGrid(suggestions: bucket.suggestions, selected: [], onToggle: addSuggestion)
                                .padding(.top, 4)
                        }
                        .listRowBackground(AppTheme.cardSurface)
                    }
                } header: {
                    Text("Suggested items")
                } footer: {
                    Text("Tap a category to see items, then tap to add.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
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
    /// category-gets-its-own-section approach as TripDetailView's own
    /// displayGroups(for:), applied to TemplateItem instead of PackingItem.
    private struct CategoryGroup: Identifiable {
        var id: String { label }
        let label: String
        let symbol: String
        let items: [TemplateItem]
    }

    private var displayGroups: [CategoryGroup] {
        let grouped = Dictionary(grouping: template.items) { item in
            ItemDisplayGroup.group(forName: item.name, categoryName: item.categoryName)
        }
        let fixedGroups = CommonProfileItems.groupOrder.compactMap { group -> CategoryGroup? in
            guard let groupItems = grouped[group], !groupItems.isEmpty else { return nil }
            return CategoryGroup(
                label: group,
                symbol: ItemDisplayGroup.symbol(for: group),
                items: groupItems.sorted { $0.name < $1.name }
            )
        }
        let fixedGroupNames = Set(CommonProfileItems.groupOrder)
        let customGroups = grouped.keys
            .filter { !fixedGroupNames.contains($0) }
            .sorted()
            .map { group in
                CategoryGroup(
                    label: group,
                    symbol: ItemDisplayGroup.symbol(for: group),
                    items: grouped[group]!.sorted { $0.name < $1.name }
                )
            }
        return fixedGroups + customGroups
    }

    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        let existingNames = Set(template.items.map { $0.name.lowercased() })
        return CommonProfileItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    /// Tapping a suggestion adds it straight to the bag — no separate
    /// pending/Save step, since once added it naturally drops out of
    /// curatedSuggestions above and the chip just disappears.
    private func addSuggestion(_ suggestion: CommonProfileItems.Suggestion) {
        let item = TemplateItem(name: suggestion.name, categoryName: suggestion.category.rawValue, template: template)
        modelContext.insert(item)
    }
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return NavigationStack {
        TemplateDetailView(template: template)
    }
    .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
