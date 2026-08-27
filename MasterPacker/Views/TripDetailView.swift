import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddItem = false

    /// Shared/household items first, then one section per traveler (trip
    /// order), then one section per pet — each sorted by category so the
    /// list reads predictably.
    private var sections: [(label: String, items: [PackingItem])] {
        var result: [(String, [PackingItem])] = []

        let shared = trip.items.filter { $0.traveler == nil && $0.pet == nil }
        if !shared.isEmpty {
            result.append(("Shared", sorted(shared)))
        }
        for traveler in trip.travelers {
            let items = trip.items.filter { $0.traveler == traveler }
            if !items.isEmpty {
                result.append((traveler.name, sorted(items)))
            }
        }
        for pet in trip.pets {
            let items = trip.items.filter { $0.pet == pet }
            if !items.isEmpty {
                result.append(("\(pet.name) (pet)", sorted(items)))
            }
        }
        return result
    }

    private func sorted(_ items: [PackingItem]) -> [PackingItem] {
        items.sorted { lhs, rhs in
            lhs.category.rawValue == rhs.category.rawValue
                ? lhs.name < rhs.name
                : lhs.category.rawValue < rhs.category.rawValue
        }
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

            ForEach(sections, id: \.label) { section in
                Section(section.label) {
                    ForEach(section.items) { item in
                        ItemRow(item: item)
                    }
                    .onDelete { offsets in
                        deleteItems(section.items, at: offsets)
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
                Image(systemName: item.category.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
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
