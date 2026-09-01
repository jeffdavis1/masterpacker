import SwiftUI
import SwiftData

/// Manage (rename or delete) custom packing categories — the ones users
/// create on the fly via "Add custom category" while adding an item
/// (AddItemView/AddTemplateItemView/AddProfileItemView). Built-in
/// categories (PackingCategory's fixed cases) aren't listed here; there's
/// nothing to manage about them.
struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var renamingCategory: CustomCategory?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if customCategories.isEmpty {
                    ContentUnavailableView(
                        "No custom categories yet",
                        systemImage: "tag",
                        description: Text("Categories you create while adding an item show up here.")
                    )
                } else {
                    List {
                        ForEach(customCategories) { category in
                            Button {
                                beginRename(category)
                            } label: {
                                HStack {
                                    Text(category.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(AppTheme.cardSurface)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Rename Category", isPresented: renameAlertBinding) {
                TextField("Category name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingCategory = nil }
                Button("Save") { commitRename() }
            } message: {
                Text("Items already using this category move to the new name too.")
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingCategory != nil },
            set: { isPresented in if !isPresented { renamingCategory = nil } }
        )
    }

    private func beginRename(_ category: CustomCategory) {
        renameText = category.name
        renamingCategory = category
    }

    private func commitRename() {
        guard let category = renamingCategory else { return }
        renamingCategory = nil
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != category.name else { return }

        // Same case-insensitive collision check "Add custom category"
        // itself uses — don't let a rename collide with a built-in
        // category or a different custom one.
        let existingNames = Set(
            PackingCategory.allCases.map { $0.rawValue.lowercased() } +
            customCategories.filter { $0.id != category.id }.map { $0.name.lowercased() }
        )
        guard !existingNames.contains(trimmed.lowercased()) else { return }

        let oldName = category.name
        category.name = trimmed
        renameCategoryUsages(from: oldName, to: trimmed)
    }

    /// Cascades a rename across every item type that can hold a free-form
    /// category name (PackingItem/TemplateItem/ProfileItem), so nothing
    /// is left pointing at the old name once the CustomCategory itself
    /// has moved on — otherwise a trip/bag/profile item would silently
    /// end up in a now-orphaned group with no matching CustomCategory
    /// entry, permanently out of sync with the rename.
    private func renameCategoryUsages(from oldName: String, to newName: String) {
        if let items = try? modelContext.fetch(FetchDescriptor<PackingItem>()) {
            for item in items where item.categoryName == oldName {
                item.categoryName = newName
            }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<TemplateItem>()) {
            for item in items where item.categoryName == oldName {
                item.categoryName = newName
            }
        }
        if let items = try? modelContext.fetch(FetchDescriptor<ProfileItem>()) {
            for item in items where item.categoryName == oldName {
                item.categoryName = newName
            }
        }
    }
}

#Preview {
    CategoryListView()
        .modelContainer(
            for: [CustomCategory.self, PackingItem.self, TemplateItem.self, ProfileItem.self],
            inMemory: true
        )
}
