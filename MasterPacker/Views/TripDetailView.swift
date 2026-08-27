import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddItem = false
    @State private var collapsedSections: Set<String> = []

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
                TripProgressHeader(trip: trip)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                TripForecastCard(trip: trip)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(sections, id: \.label) { section in
                Section {
                    if !collapsedSections.contains(section.label) {
                        ForEach(section.items) { item in
                            ItemRow(item: item)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { offsets in
                            deleteItems(section.items, at: offsets)
                        }
                    }
                } header: {
                    SectionHeaderButton(
                        label: section.label,
                        packedCount: section.items.filter(\.isPacked).count,
                        totalCount: section.items.count,
                        isCollapsed: collapsedSections.contains(section.label)
                    ) {
                        toggleSection(section.label)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenGradient.ignoresSafeArea())
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

    private func toggleSection(_ label: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedSections.contains(label) {
                collapsedSections.remove(label)
            } else {
                collapsedSections.insert(label)
            }
        }
    }
}

/// A tappable section header showing who the group is for, its packed
/// count, and a chevron indicating expanded/collapsed state.
private struct SectionHeaderButton: View {
    let label: String
    let packedCount: Int
    let totalCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(label.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(0.6)
                Spacer()
                Text("\(packedCount)/\(totalCount)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TripProgressHeader: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("\(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s") · \(trip.destination)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            ProgressBar(progress: trip.progress)

            Text("\(trip.packedCount) of \(trip.items.count) packed")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(18)
        .background(AppTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius + 4, style: .continuous))
        .shadow(color: AppTheme.navy.opacity(0.25), radius: 16, y: 10)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

/// Horizontally-scrolling forecast for the trip's dates, shown prominently
/// right below the progress header. Renders nothing if the destination
/// can't be geocoded or no forecast is available yet — no error state,
/// it just quietly stays empty.
private struct TripForecastCard: View {
    let trip: Trip
    @State private var forecasts: [DayForecast] = []
    @State private var didLoad = false

    var body: some View {
        Group {
            if !forecasts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Forecast", systemImage: "cloud.sun.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.navy)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(forecasts) { day in
                                ForecastDayColumn(day: day)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(16)
                .floatingCard()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            forecasts = await WeatherService.shared.forecast(destination: trip.destination, startDate: trip.startDate, days: 7)
        }
    }
}

private struct ForecastDayColumn: View {
    let day: DayForecast

    var body: some View {
        VStack(spacing: 6) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Image(systemName: day.symbolName)
                .font(.title3)
                .foregroundStyle(AppTheme.brand)
            Text("\(Int(day.highTemperature.rounded()))°")
                .font(.system(.caption, design: .rounded, weight: .bold))
            Text("\(Int(day.lowTemperature.rounded()))°")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 46)
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
                    .foregroundStyle(item.isPacked ? AppTheme.sage : .secondary)
                Image(systemName: item.displaySymbol)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .floatingCard(radius: AppTheme.cornerRadius - 2)
    }
}
