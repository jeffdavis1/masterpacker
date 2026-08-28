import SwiftUI
import SwiftData

/// Entry point for saved packing templates — presented as a sheet from
/// `TripListView`.
struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PackingTemplate.name) private var templates: [PackingTemplate]
    @State private var isPresentingAddTemplate = false
    @State private var path = NavigationPath()

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
                        }
                        .onDelete(perform: deleteTemplates)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
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
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
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
                Text("\(template.items.count) item\(template.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .floatingCard()
    }
}

#Preview {
    TemplateListView()
        .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
