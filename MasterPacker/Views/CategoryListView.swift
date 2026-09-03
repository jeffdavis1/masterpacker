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
    @State private var deletingCategory: CustomCategory?
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            Group {
                if customCategories.isEmpty {
                    ContentUnavailableView {
                        Label("No custom categories yet", systemImage: "tag")
                    } description: {
                        Text("Categories you create while adding an item show up here, or add one directly below.")
                    } actions: {
                        Button("Add Category") { isAddingCategory = true }
                    }
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
                                    deletingCategory = category
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }
            }
            .alert("New Category", isPresented: $isAddingCategory) {
                TextField("Category name", text: $newCategoryName)
                Button("Cancel", role: .cancel) { newCategoryName = "" }
                Button("Add") { addCategory() }
            } message: {
                Text("Shows up as a category the next time you're adding an item.")
            }
            .alert("Rename Category", isPresented: renameAlertBinding) {
                TextField("Category name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingCategory = nil }
                Button("Save") { commitRename() }
            } message: {
                Text("Items already using this category move to the new name too.")
            }
            .alert(
                "Delete “\(deletingCategory?.name ?? "")”?",
                isPresented: deleteAlertBinding
            ) {
                Button("Cancel", role: .cancel) { deletingCategory = nil }
                Button("Delete", role: .destructive) { commitDelete() }
            } message: {
                Text("Items already using this category move to Miscellaneous instead of staying on a deleted one.")
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingCategory != nil },
            set: { isPresented in if !isPresented { renamingCategory = nil } }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingCategory != nil },
            set: { isPresented in if !isPresented { deletingCategory = nil } }
        )
    }

    /// Same collision rule as the inline "Add custom category" flow on
    /// AddItemView/AddTemplateItemView/AddProfileItemView — case-
    /// insensitive against both built-in categories and existing custom
    /// ones. A collision here just quietly does nothing (there's no item
    /// being added to fall back to selecting, unlike those flows).
    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        newCategoryName = ""
        guard !trimmed.isEmpty else { return }

        let existingNames = Set(
            PackingCategory.allCases.map { $0.rawValue.lowercased() } + customCategories.map { $0.name.lowercased() }
        )
        guard !existingNames.contains(trimmed.lowercased()) else { return }

        modelContext.insert(CustomCategory(name: trimmed))
        AnalyticsService.customCategoryCreated()
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
        reassignCategoryUsages(from: oldName, to: trimmed)
    }

    /// Reassigns every item still using the deleted category to
    /// Miscellaneous, then removes the CustomCategory record itself.
    ///
    /// Earlier version of this screen only removed the CustomCategory
    /// record and left existing items' categoryName untouched — looked
    /// fine at a glance (a "deleted" category doesn't show anywhere
    /// obviously wrong), but a traveler/pet profile's saved always-pack
    /// item, or a My Bag template item, could still be holding that exact
    /// categoryName string. Add that traveler/apply that template to a
    /// brand new trip, and AddTripView copies categoryName straight
    /// across — resurrecting the "deleted" category on a trip that never
    /// existed when it was deleted. Reassigning here, not just at the
    /// CustomCategory level, is what actually makes delete mean delete.
    private func commitDelete() {
        guard let category = deletingCategory else { return }
        deletingCategory = nil
        reassignCategoryUsages(from: category.name, to: PackingCategory.misc.rawValue)
        modelContext.delete(category)
        AnalyticsService.customCategoryDeleted()
    }

    /// Sweeps every item type that can hold a free-form category name
    /// (PackingItem/TemplateItem/ProfileItem) and reassigns any using
    /// `oldName` to `newName` — shared by both rename (moves usages to
    /// the new name) and delete (moves usages to Miscellaneous).
    private func reassignCategoryUsages(from oldName: String, to newName: String) {
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
