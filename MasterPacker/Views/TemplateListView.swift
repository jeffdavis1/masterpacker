import SwiftUI
import SwiftData

/// Entry point for saved packing templates — the "My Bag" tab in
/// RootTabView.
struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingTemplate.name) private var templates: [PackingTemplate]
    @State private var isPresentingAddTemplate = false
    @State private var path = NavigationPath()

    @State private var renamingTemplate: PackingTemplate?
    @State private var renameText = ""

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No bags yet",
                        systemImage: "bag",
                        description: Text("Save a reusable packing list once, then add it to any trip.")
                    )
                } else {
                    List {
                        ForEach(templates) { template in
                            NavigationLink(value: template) {
                                TemplateRow(template: template)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(template)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                // Renaming lives here instead of a pencil
                                // button on the bag's own detail screen —
                                // keeps that screen's toolbar free for
                                // Add/Save, which get reached far more often.
                                Button {
                                    beginRename(template)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(AppTheme.brand)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("My Bag")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: PackingTemplate.self) { template in
                TemplateDetailView(template: template)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddTemplate = true
                    } label: {
                        Label("New Bag", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddTemplate) {
                // Go straight to the new template's item list once it's
                // created, instead of dropping back to this list.
                NewTemplateView { template in
                    path.append(template)
                }
            }
            .alert("Rename Bag", isPresented: renameAlertBinding) {
                TextField("Bag name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingTemplate = nil }
                Button("Save") { commitRename() }
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingTemplate != nil },
            set: { isPresented in if !isPresented { renamingTemplate = nil } }
        )
    }

    private func beginRename(_ template: PackingTemplate) {
        renameText = template.name
        renamingTemplate = template
    }

    private func commitRename() {
        guard let template = renamingTemplate else { return }
        renamingTemplate = nil
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        template.name = trimmed
    }
}

private struct TemplateRow: View {
    let template: PackingTemplate

    var body: some View {
        HStack(spacing: 13) {
            IconBadge(systemImage: "bag")

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.system(.headline, design: .rounded))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .floatingCard()
    }

    /// "6 items" for an unowned bag, "6 items · Jeff" (or "· Jeff, Sarah")
    /// once it's been assigned to specific travelers — otherwise there's
    /// no way to tell an owned bag apart from a general-purpose one
    /// without opening it.
    private var subtitle: String {
        let itemCount = "\(template.items.count) item\(template.items.count == 1 ? "" : "s")"
        guard !template.owners.isEmpty else { return itemCount }
        let names = template.owners.map(\.name).sorted().joined(separator: ", ")
        return "\(itemCount) · \(names)"
    }
}

#Preview {
    TemplateListView()
        .modelContainer(
            for: [PackingTemplate.self, TemplateItem.self, TravelerProfile.self, ProfileItem.self],
            inMemory: true
        )
}
