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
                    .listRowBackground(Color.white)
                }
                .onDelete(perform: deleteItems)
            }

            Button {
                isAddingItem = true
            } label: {
                Label("Add item", systemImage: "plus")
            }
            .listRowBackground(Color.white)
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
}

#Preview {
    let template = PackingTemplate(name: "Preview")
    return NavigationStack {
        TemplateDetailView(template: template)
    }
    .modelContainer(for: [PackingTemplate.self, TemplateItem.self], inMemory: true)
}
