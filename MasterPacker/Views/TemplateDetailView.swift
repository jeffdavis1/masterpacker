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
                ForEach(template.items) { item in
                    HStack {
                        Image(systemName: item.displaySymbol)
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
                isAddingItem = true
            } label: {
                Label("Add item", systemImage: "plus")
            }
            .listRowBackground(AppTheme.cardSurface)

            if !curatedSuggestions.isEmpty {
                Section {
                    SuggestionChipGrid(suggestions: curatedSuggestions, selected: [], onToggle: addSuggestion)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Suggested items")
                } footer: {
                    Text("A few things almost everyone packs — tap to add.")
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

    private func deleteItems(at offsets: IndexSet) {
        let items = template.items
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private var curatedSuggestions: [CommonProfileItems.Suggestion] {
        let existingNames = Set(template.items.map { $0.name.lowercased() })
        return CommonProfileItems.all.filter { !existingNames.contains($0.name.lowercased()) }
    }

    /// Tapping a suggestion adds it straight to the bag — no separate
    /// pending/Save step, since once added it naturally drops out of
    /// curatedSuggestions above and the chip just disappears.
    private func addSuggestion(_ suggestion: CommonProfileItems.Suggestion) {
        let item = TemplateItem(name: suggestion.name, category: suggestion.category, template: template)
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
