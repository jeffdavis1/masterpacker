import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddItem = false

    private var groupedItems: [(category: PackingCategory, items: [PackingItem])] {
        Dictionary(grouping: trip.items, by: \.category)
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { (category: $0.key, items: $0.value) }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: trip.progress) {
                        Text("\(trip.packedCount) of \(trip.items.count) packed")
                            .font(.subheadline)
                    }
                    Text("\(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s") · \(trip.destination)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            ForEach(groupedItems, id: \.category) { group in
                Section(group.category.rawValue) {
                    ForEach(group.items) { item in
                        ItemRow(item: item)
                    }
                    .onDelete { offsets in
                        deleteItems(group.items, at: offsets)
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddItem) {
            AddItemView(trip: trip)
        }
    }

    private func deleteItems(_ items: [PackingItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

private struct ItemRow: View {
    @Bindable var item: PackingItem

    var body: some View {
        Button {
            item.isPacked.toggle()
        } label: {
            HStack {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPacked ? .green : .secondary)
                Text(item.name)
                    .strikethrough(item.isPacked)
                    .foregroundStyle(item.isPacked ? .secondary : .primary)
                if item.quantity > 1 {
                    Spacer()
                    Text("×\(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
