import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingAddItem = false
    @State private var isPresentingEditTrip = false
    @State private var isPresentingApplyTemplate = false
    @State private var collapsedSections: Set<String> = []
    @State private var isPresentingShareSheet = false
    @State private var groupingMode: GroupingMode = .people
    /// Only meaningful in Luggage grouping — lets picking a bag apply to
    /// every checked item at once instead of one menu tap per item.
    @State private var isSelectingForBulkAssign = false
    @State private var selectedItemIDs: Set<PersistentIdentifier> = []

    private enum GroupingMode: String, CaseIterable, Identifiable {
        case people = "People"
        case luggage = "Luggage"
        var id: String { rawValue }
    }

    /// One category's items within a traveler/pet/shared/luggage group —
    /// label/symbol rather than a raw PackingCategory, since a human
    /// section uses ItemDisplayGroup's 9 browsing groups (the same ones
    /// the Suggested Items picker uses) while a pet's section still uses
    /// PackingCategory directly. See categoryGroups/displayGroups below.
    private struct CategoryGroup: Identifiable {
        var id: String { label }
        let label: String
        let symbol: String
        let items: [PackingItem]
    }

    /// One collapsible group of items in the packing list — a traveler,
    /// "Shared", a pet, "Unassigned", or a piece of luggage, depending on
    /// groupingMode. A named struct rather than a tuple so sections,
    /// peopleSections, and luggageSections all share one unambiguous
    /// type — Swift doesn't reliably unify differently-labeled tuple
    /// types inside a generic like Array across separate return
    /// statements the way it does for a single direct return.
    private struct TripSection: Identifiable {
        var id: String { label }
        let label: String
        let categoryGroups: [CategoryGroup]
        let items: [PackingItem]
    }

    private var sections: [TripSection] {
        switch groupingMode {
        case .people: return peopleSections
        case .luggage: return luggageSections
        }
    }

    /// Shared/household items first, then one group per traveler (trip
    /// order), then one group per pet — each broken down further into
    /// sub-groups so e.g. a traveler's electronics sit together, separate
    /// from their toiletries. Pet sections use displayGroups: false — see
    /// its doc comment for why pets stay on the plain PackingCategory
    /// grouping instead of the 9-group system everything else uses.
    private var peopleSections: [TripSection] {
        var result: [TripSection] = []

        func addSection(_ label: String, _ items: [PackingItem], useDisplayGroups: Bool) {
            guard !items.isEmpty else { return }
            let groups = useDisplayGroups ? displayGroups(for: items) : categoryGroups(for: items)
            result.append(TripSection(label: label, categoryGroups: groups, items: items))
        }

        addSection("Shared", trip.items.filter { $0.traveler == nil && $0.pet == nil }, useDisplayGroups: true)
        for traveler in trip.travelers {
            addSection(traveler.name, trip.items.filter { $0.traveler == traveler }, useDisplayGroups: true)
        }
        for pet in trip.pets {
            addSection("\(pet.name) (pet)", trip.items.filter { $0.pet == pet }, useDisplayGroups: false)
        }
        return result
    }

    /// One group per piece of luggage first (in the order it was added),
    /// then Unassigned last — so the bags a user actually cares about
    /// packing show up front. Unlike the People grouping, a luggage
    /// section shows even when empty (0/0), so e.g. "Checked Bag" is
    /// visible as a real, ready-to-fill destination the moment it
    /// exists, not only once something's already in it. Always uses
    /// displayGroups — a bag can mix a traveler's clothes with a pet's
    /// supplies, so there's no single "whose bag is this" to key the
    /// pets-stay-on-PackingCategory exception off of.
    private var luggageSections: [TripSection] {
        var result: [TripSection] = []

        for bag in trip.luggage {
            let items = trip.items.filter { $0.luggage?.persistentModelID == bag.persistentModelID }
            result.append(TripSection(label: bag.name, categoryGroups: displayGroups(for: items), items: items))
        }

        let unassigned = trip.items.filter { $0.luggage == nil }
        if !unassigned.isEmpty {
            result.append(TripSection(label: "Unassigned", categoryGroups: displayGroups(for: unassigned), items: unassigned))
        }
        return result
    }

    /// Used only for pet sections. Every pet item already shares one
    /// PackingCategory (.petSupplies — see PackingRulesEngine.petItems),
    /// so this already collapses a pet's section to one correctly-named
    /// "PET SUPPLIES" header; running it through ItemDisplayGroup instead
    /// would just relabel that same single header "Miscellaneous" — a
    /// worse name for the same one-group outcome, since none of the 9
    /// human-oriented browsing groups actually fit a leash or a bag of
    /// kibble.
    private func categoryGroups(for items: [PackingItem]) -> [CategoryGroup] {
        let grouped = Dictionary(grouping: items, by: \.category)
        return grouped.keys
            .sorted { $0.rawValue < $1.rawValue }
            .map { category in
                CategoryGroup(
                    label: category.rawValue.uppercased(),
                    symbol: category.symbol,
                    items: grouped[category]!.sorted { $0.name < $1.name }
                )
            }
    }

    /// Used for every section except pets — groups by ItemDisplayGroup's
    /// 9 browsing groups (Clothing Essentials, Footwear, …), the same
    /// taxonomy the Suggested Items picker uses, so the trip's own
    /// packing list reads with the same categories rather than the
    /// coarser 7-value PackingCategory.
    private func displayGroups(for items: [PackingItem]) -> [CategoryGroup] {
        let grouped = Dictionary(grouping: items) { item in
            ItemDisplayGroup.group(forName: item.name, category: item.category)
        }
        return CommonProfileItems.groupOrder.compactMap { group in
            guard let groupItems = grouped[group], !groupItems.isEmpty else { return nil }
            return CategoryGroup(
                label: group.uppercased(),
                symbol: ItemDisplayGroup.symbol(for: group),
                items: groupItems.sorted { $0.name < $1.name }
            )
        }
    }

    /// Watched so the "still unpacked" reminder's item count stays
    /// current as items are checked off, added, or removed.
    private var unpackedCount: Int {
        trip.items.filter { !$0.isPacked }.count
    }

    var body: some View {
        List {
            Section {
                TripProgressHeader(trip: trip)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if !trip.travelers.isEmpty || !trip.pets.isEmpty {
                    WhosGoingCard(trip: trip)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                TripForecastCard(trip: trip)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Picker("Group by", selection: $groupingMode) {
                    ForEach(GroupingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onChange(of: groupingMode) { _, newMode in
                    if newMode == .luggage {
                        Luggage.ensureDefaults(for: trip, in: modelContext)
                    } else {
                        // Bulk-select only makes sense while looking at
                        // luggage — leaving that view shouldn't leave a
                        // stale selection or the Select bar behind.
                        isSelectingForBulkAssign = false
                        selectedItemIDs.removeAll()
                    }
                }
            }

            ForEach(sections) { section in
                Section {
                    if !collapsedSections.contains(section.label) {
                        ForEach(section.categoryGroups) { group in
                            CategoryHeaderRow(label: group.label, symbol: group.symbol)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 2, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                            ForEach(group.items) { item in
                                ItemRow(
                                    item: item,
                                    trip: groupingMode == .luggage ? trip : nil,
                                    isSelectionMode: isSelectingForBulkAssign,
                                    isSelected: selectedItemIDs.contains(item.persistentModelID),
                                    onToggleSelect: { toggleSelection(item) }
                                )
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            .onDelete { offsets in
                                deleteItems(group.items, at: offsets)
                            }
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
        .safeAreaInset(edge: .bottom) {
            if isSelectingForBulkAssign && !selectedItemIDs.isEmpty {
                BulkLuggageAssignBar(
                    count: selectedItemIDs.count,
                    trip: trip,
                    onAssign: { bag in
                        assignSelection(to: bag)
                    }
                )
            }
        }
        .navigationTitle(trip.name)
        .refreshable {
            // Pulls a participant's edits (item packed state) into this
            // trip's local SwiftData copy, if it's shared — the owner had
            // no way to manually do this before, only push notifications.
            await TripSharingService.shared.syncSharedTrips()
        }
        .onChange(of: unpackedCount) { _, _ in
            Task { await NotificationManager.shared.scheduleTripReminders(for: trip) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingEditTrip = true
                } label: {
                    Label("Edit Trip", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingShareSheet = true
                } label: {
                    Label("Share Trip", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isPresentingAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    Button {
                        isPresentingApplyTemplate = true
                    } label: {
                        Label("Add from My Bag", systemImage: "bag")
                    }
                    if !trip.notes.isEmpty {
                        Button {
                            addNotesSuggestions()
                        } label: {
                            Label("Suggest from Notes", systemImage: "text.bubble")
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            if groupingMode == .luggage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelectingForBulkAssign ? "Done" : "Select") {
                        isSelectingForBulkAssign.toggle()
                        if !isSelectingForBulkAssign {
                            selectedItemIDs.removeAll()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingAddItem) {
            AddItemView(trip: trip)
        }
        .sheet(isPresented: $isPresentingEditTrip) {
            EditTripView(trip: trip, onDelete: { dismiss() })
        }
        .sheet(isPresented: $isPresentingApplyTemplate) {
            ApplyTemplateView(trip: trip)
        }
        .background(CloudSharingPresenter(trip: trip, isPresented: $isPresentingShareSheet))
    }

    private func deleteItems(_ items: [PackingItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        Task { await TripSharingService.shared.resyncIfShared(trip) }
    }

    private func toggleSelection(_ item: PackingItem) {
        let id = item.persistentModelID
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    /// Assigns every currently-selected item to `bag` (nil means
    /// Unassigned) in one shot, then exits selection mode — the whole
    /// point of bulk-select is not needing to reopen a menu per item.
    private func assignSelection(to bag: Luggage?) {
        for item in trip.items where selectedItemIDs.contains(item.persistentModelID) {
            item.luggage = bag
        }
        isSelectingForBulkAssign = false
        selectedItemIDs.removeAll()
    }

    /// Explicit, on-demand version of what AddTripView already does
    /// automatically at creation — re-scans trip.notes for activity
    /// keywords (e.g. "hiking excursion") and adds any gear that isn't
    /// already in the packing list. Only reachable when trip.notes isn't
    /// empty (see the Add menu above), and only ever adds — never
    /// removes or changes an existing item — so it's safe to tap more
    /// than once as notes evolve.
    private func addNotesSuggestions() {
        let existingNames = Set(trip.items.map { $0.name.lowercased() })
        var addedCount = 0

        for generated in PackingRulesEngine.suggestedItemsFromNotes(for: trip) {
            guard !existingNames.contains(generated.name.lowercased()) else { continue }

            let traveler: Traveler?
            let pet: Pet?
            switch generated.assignee {
            case .shared:
                traveler = nil
                pet = nil
            case .traveler(let t):
                traveler = t
                pet = nil
            case .pet(let p):
                traveler = nil
                pet = p
            }

            let item = PackingItem(
                name: generated.name,
                category: generated.category,
                quantity: generated.quantity,
                trip: trip,
                traveler: traveler,
                pet: pet
            )
            modelContext.insert(item)
            addedCount += 1
        }

        guard addedCount > 0 else { return }
        Task {
            await NotificationManager.shared.scheduleTripReminders(for: trip)
            await TripSharingService.shared.resyncIfShared(trip)
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

/// A small non-interactive label marking one category's items within a
/// traveler/pet/shared group — e.g. "ELECTRONICS" above phone charger,
/// battery pack, etc. Unlike the outer traveler group, these aren't
/// individually collapsible; they're just a visual break.
private struct CategoryHeaderRow: View {
    let label: String
    let symbol: String

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.secondary.opacity(0.8))
    }
}

/// Floating bar shown while bulk-selecting in Luggage grouping — lets one
/// menu tap assign every selected item to a bag at once, instead of
/// reopening ItemRow's per-item menu N times.
private struct BulkLuggageAssignBar: View {
    let count: Int
    let trip: Trip
    let onAssign: (Luggage?) -> Void

    var body: some View {
        HStack {
            Text("\(count) selected")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Spacer()
            Menu {
                Button("Unassigned") { onAssign(nil) }
                if !trip.luggage.isEmpty {
                    Divider()
                    ForEach(trip.luggage) { bag in
                        Button(bag.name) { onAssign(bag) }
                    }
                }
            } label: {
                Label("Assign to Luggage", systemImage: "bag.fill")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

private struct TripProgressHeader: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text(trip.destination)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            Text("\(tripDateRangeText(from: trip.startDate, to: trip.endDate)) · \(trip.durationInDays) day\(trip.durationInDays == 1 ? "" : "s")")
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

/// A quick "who's on this trip" summary — travelers and pets as chips,
/// shown right below the progress header. Previously the only place
/// travelers/pets showed up at all was as section headers buried further
/// down in the packing list.
private struct WhosGoingCard: View {
    let trip: Trip
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Who's Going", systemImage: "person.2.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(trip.travelers) { traveler in
                    WhosGoingChip(name: traveler.name, symbol: traveler.ageBracket.symbol)
                }
                ForEach(trip.pets) { pet in
                    WhosGoingChip(name: pet.name, symbol: pet.species.symbol)
                }
            }
        }
        .padding(16)
        .floatingCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct WhosGoingChip: View {
    let name: String
    let symbol: String

    var body: some View {
        Label(name, systemImage: symbol)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.brand.opacity(0.12))
            .foregroundStyle(AppTheme.brand)
            .clipShape(Capsule())
    }
}

/// Horizontally-scrolling forecast for the trip's dates, shown prominently
/// right below the progress header. Renders nothing if the destination
/// can't be geocoded or no forecast is available yet — no error state,
/// it just quietly stays empty.
private struct TripForecastCard: View {
    let trip: Trip
    @State private var forecasts: [DayForecast] = []

    var body: some View {
        Group {
            if !forecasts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Forecast", systemImage: "cloud.sun.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

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
        // Re-fetches automatically if the trip's destination or start date
        // changes (e.g. after editing the trip) — WeatherService caches
        // internally, so re-running this for unchanged values is cheap.
        .task(id: "\(trip.destination)|\(trip.startDate)") {
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
    /// Non-nil only when the list is grouped by Luggage — shows a small
    /// "assign to bag" control so items can be sorted while looking right
    /// at the bag they're being packed into. Deliberately absent in the
    /// default People grouping, so that view stays exactly as it was.
    let trip: Trip?
    /// The three below are only meaningful when trip != nil (bulk-select
    /// only exists in Luggage grouping). While selecting, the whole row
    /// becomes one tap target for toggling selection — packed-toggle and
    /// the per-item luggage menu are hidden rather than left active
    /// alongside it, so there's never ambiguity about what a tap does.
    var isSelectionMode = false
    var isSelected = false
    var onToggleSelect: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddLuggage = false
    @State private var newLuggageName = ""

    var body: some View {
        Group {
            if isSelectionMode {
                selectionRow
            } else {
                normalRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .floatingCard(radius: AppTheme.cornerRadius - 2)
        .alert("New Luggage", isPresented: $isPresentingAddLuggage) {
            TextField("Name", text: $newLuggageName)
            Button("Cancel", role: .cancel) { newLuggageName = "" }
            Button("Add") { addLuggageAndAssign() }
        } message: {
            Text("e.g. \"Kids' backpack\"")
        }
    }

    private var normalRow: some View {
        HStack(spacing: 8) {
            Button {
                item.isPacked.toggle()
                AnalyticsService.itemPackedToggled(isPacked: item.isPacked)
                // No-ops if this item's trip isn't shared — cheap to call
                // unconditionally so a shared trip's participant sees the
                // change on their next refresh without a full re-share.
                Task { await TripSharingService.shared.syncItemPackedIfShared(item) }
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
                    Spacer()
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if let trip {
                luggageMenu(trip: trip)
            }
        }
    }

    private var selectionRow: some View {
        Button {
            onToggleSelect?()
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.brand : .secondary)
                Image(systemName: item.displaySymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(item.name)
                    .foregroundStyle(.primary)
                Spacer()
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func luggageMenu(trip: Trip) -> some View {
        Menu {
            Button("Unassigned") { item.luggage = nil }
            if !trip.luggage.isEmpty {
                Divider()
                ForEach(trip.luggage) { bag in
                    Button(bag.name) { item.luggage = bag }
                }
            }
            Divider()
            Button {
                isPresentingAddLuggage = true
            } label: {
                Label("Add New Luggage…", systemImage: "plus")
            }
        } label: {
            Label(item.luggage?.name ?? "Unassigned", systemImage: "bag.fill")
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.brand.opacity(0.1))
                .foregroundStyle(AppTheme.brand)
                .clipShape(Capsule())
        }
    }

    /// Creates a new custom Luggage for this item's trip and immediately
    /// assigns the item to it — one action instead of "create, then find
    /// it in the menu again to assign".
    private func addLuggageAndAssign() {
        let trimmed = newLuggageName.trimmingCharacters(in: .whitespaces)
        newLuggageName = ""
        guard !trimmed.isEmpty, let trip else { return }
        let bag = Luggage(name: trimmed, trip: trip)
        modelContext.insert(bag)
        item.luggage = bag
    }
}
