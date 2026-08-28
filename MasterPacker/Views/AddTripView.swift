import SwiftUI
import SwiftData

struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PackingTemplate.name) private var savedTemplates: [PackingTemplate]

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 3)
    @State private var travelMethod: TravelMethod = .car
    @State private var selectedActivities: Set<Activity> = []
    @State private var notes = ""
    @State private var selectedProfiles: [TravelerProfile] = []
    @State private var selectedPetProfiles: [PetProfile] = []
    @State private var selectedTemplates: [PackingTemplate] = []
    @State private var generateSuggestions = true
    @State private var isPresentingTravelerChooser = false
    @State private var isPresentingPetChooser = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Trip name", text: $name)
                    DestinationField(destination: $destination)
                    QuickDateField(label: "Start", date: $startDate)
                    QuickDateField(label: "End", date: $endDate, minimumDate: startDate)
                    Picker("Travel method", selection: $travelMethod) {
                        ForEach(TravelMethod.allCases) { method in
                            Label(method.rawValue, systemImage: method.symbol).tag(method)
                        }
                    }
                }

                Section {
                    ForEach(selectedProfiles) { profile in
                        HStack {
                            Text(profile.name)
                            Spacer()
                            Button(role: .destructive) {
                                selectedProfiles.removeAll { $0.id == profile.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        isPresentingTravelerChooser = true
                    } label: {
                        Label("Add traveler", systemImage: "plus")
                    }
                } header: {
                    Text("Travelers")
                } footer: {
                    Text("Their always-pack items come along automatically.")
                }

                Section("Activities") {
                    ActivityChipGrid(selected: $selectedActivities)
                    TextField("Notes (e.g. \"visiting grandma\")", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    ForEach(selectedPetProfiles) { profile in
                        HStack {
                            Text(profile.name)
                            Spacer()
                            Button(role: .destructive) {
                                selectedPetProfiles.removeAll { $0.id == profile.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        isPresentingPetChooser = true
                    } label: {
                        Label("Add pet", systemImage: "plus")
                    }
                } header: {
                    Text("Pets")
                } footer: {
                    Text("Their always-pack items come along automatically.")
                }

                if !savedTemplates.isEmpty {
                    Section {
                        TemplateChipGrid(templates: savedTemplates, selected: $selectedTemplates)
                    } header: {
                        Text("From My Bag")
                    } footer: {
                        Text("Adds each selected bag's items to this trip's shared list.")
                    }
                }

                Section {
                    Toggle("Generate suggested packing list", isOn: $generateSuggestions)
                } footer: {
                    Text("Adds a starter checklist based on travelers, activities, trip length, and the destination's forecast. You can edit it afterward.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(!isValid)
                    }
                }
            }
            .sheet(isPresented: $isPresentingTravelerChooser) {
                TravelerChooserView(selectedProfiles: $selectedProfiles)
            }
            .sheet(isPresented: $isPresentingPetChooser) {
                PetChooserView(selectedProfiles: $selectedPetProfiles)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedProfiles.isEmpty
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trip = Trip(
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            travelMethod: travelMethod,
            activities: selectedActivities,
            notes: notes
        )
        modelContext.insert(trip)

        let travelerModels = selectedProfiles.map { profile -> Traveler in
            let traveler = Traveler(name: profile.name, ageBracket: profile.ageBracket, trip: trip)
            modelContext.insert(traveler)
            return traveler
        }

        let petModels = selectedPetProfiles.map { profile -> Pet in
            let pet = Pet(name: profile.name, species: profile.species, trip: trip)
            modelContext.insert(pet)
            return pet
        }

        trip.travelers = travelerModels
        trip.pets = petModels

        if generateSuggestions {
            let forecast = await WeatherService.shared.forecast(
                destination: trip.destination,
                startDate: trip.startDate,
                days: min(trip.durationInDays, 16)
            )
            // Seed the weather-change watcher's baseline with the same
            // fetch — no extra network call, and it means the very first
            // background check has something to compare against.
            NotificationManager.shared.establishWeatherBaseline(forecast, for: trip)
            for generated in PackingRulesEngine.generate(for: trip, weatherForecast: forecast) {
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
            }
        }

        // Always-pack items from each traveler's/pet's saved profile aren't
        // gated by the "generate suggested packing list" toggle above — the
        // whole point of saving them is that you always want them.
        for (profile, traveler) in zip(selectedProfiles, travelerModels) {
            for profileItem in profile.alwaysItems {
                // Profile items can use a custom category (text-only, no
                // matching PackingCategory case); fall back to .misc for
                // the actual trip item in that case.
                let item = PackingItem(
                    name: profileItem.name,
                    category: PackingCategory(rawValue: profileItem.categoryName) ?? .misc,
                    quantity: profileItem.quantity,
                    trip: trip,
                    traveler: traveler
                )
                modelContext.insert(item)
            }
        }

        for (profile, pet) in zip(selectedPetProfiles, petModels) {
            for profileItem in profile.alwaysItems {
                let item = PackingItem(
                    name: profileItem.name,
                    category: PackingCategory(rawValue: profileItem.categoryName) ?? .misc,
                    quantity: profileItem.quantity,
                    trip: trip,
                    pet: pet
                )
                modelContext.insert(item)
            }
        }

        // Selected templates' items land in the shared/household bucket
        // (no traveler/pet assignee), same as ApplyTemplateView.
        for template in selectedTemplates {
            for templateItem in template.items {
                let item = PackingItem(
                    name: templateItem.name,
                    category: templateItem.category,
                    quantity: templateItem.quantity,
                    trip: trip
                )
                modelContext.insert(item)
            }
        }

        await NotificationManager.shared.scheduleTripReminders(for: trip)
        AnalyticsService.tripCreated(
            travelerCount: trip.travelers.count,
            petCount: trip.pets.count,
            activityCount: selectedActivities.count,
            travelMethod: travelMethod,
            generatedSuggestions: generateSuggestions
        )
        if !selectedTemplates.isEmpty {
            AnalyticsService.bagAppliedToTrip()
        }

        dismiss()
    }
}

/// Lets the user select multiple saved travelers (tap to toggle, stays
/// open) or create a new one on the spot, then confirm with Done — unlike
/// a confirmation dialog, this doesn't close after every tap.
private struct TravelerChooserView: View {
    @Binding var selectedProfiles: [TravelerProfile]
    @Query(sort: \TravelerProfile.name) private var savedProfiles: [TravelerProfile]
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingNewProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if savedProfiles.isEmpty {
                    ContentUnavailableView(
                        "No saved travelers yet",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Create one to add them to this trip.")
                    )
                } else {
                    List {
                        ForEach(savedProfiles) { profile in
                            Button {
                                toggle(profile)
                            } label: {
                                HStack {
                                    Text(profile.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if isSelected(profile) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.brand)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .listRowBackground(AppTheme.cardSurface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Add Travelers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingNewProfile = true
                    } label: {
                        Label("Create New Traveler", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingNewProfile) {
                NewProfileView { profile in
                    if !isSelected(profile) {
                        selectedProfiles.append(profile)
                    }
                }
            }
        }
    }

    private func isSelected(_ profile: TravelerProfile) -> Bool {
        selectedProfiles.contains { $0.id == profile.id }
    }

    private func toggle(_ profile: TravelerProfile) {
        if isSelected(profile) {
            selectedProfiles.removeAll { $0.id == profile.id }
        } else {
            selectedProfiles.append(profile)
        }
    }
}

/// Same as TravelerChooserView, but for saved pets.
private struct PetChooserView: View {
    @Binding var selectedProfiles: [PetProfile]
    @Query(sort: \PetProfile.name) private var savedProfiles: [PetProfile]
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingNewProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if savedProfiles.isEmpty {
                    ContentUnavailableView(
                        "No saved pets yet",
                        systemImage: "pawprint",
                        description: Text("Create one to add them to this trip.")
                    )
                } else {
                    List {
                        ForEach(savedProfiles) { profile in
                            Button {
                                toggle(profile)
                            } label: {
                                HStack {
                                    Text(profile.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if isSelected(profile) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.brand)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .listRowBackground(AppTheme.cardSurface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.screenGradient.ignoresSafeArea())
            .navigationTitle("Add Pets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingNewProfile = true
                    } label: {
                        Label("Create New Pet", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingNewProfile) {
                NewPetProfileView { profile in
                    if !isSelected(profile) {
                        selectedProfiles.append(profile)
                    }
                }
            }
        }
    }

    private func isSelected(_ profile: PetProfile) -> Bool {
        selectedProfiles.contains { $0.id == profile.id }
    }

    private func toggle(_ profile: PetProfile) {
        if isSelected(profile) {
            selectedProfiles.removeAll { $0.id == profile.id }
        } else {
            selectedProfiles.append(profile)
        }
    }
}

/// A date field that reads as a normal Form row (label + formatted date)
/// but opens a `.graphical` calendar in a popover on tap and dismisses
/// itself the instant a date is picked — unlike the stock compact
/// DatePicker, whose popover otherwise stays open until the user taps
/// elsewhere to close it. Shared by AddTripView and EditTripView.
struct QuickDateField: View {
    let label: String
    @Binding var date: Date
    var minimumDate: Date?
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                Text(date, style: .date).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            Group {
                if let minimumDate {
                    DatePicker(label, selection: $date, in: minimumDate..., displayedComponents: .date)
                } else {
                    DatePicker(label, selection: $date, displayedComponents: .date)
                }
            }
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .frame(minWidth: 320, minHeight: 360)
            .presentationCompactAdaptation(.popover)
            .onChange(of: date) {
                isPresented = false
            }
        }
    }
}

private struct ActivityChipGrid: View {
    @Binding var selected: Set<Activity>

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Activity.allCases) { activity in
                let isSelected = selected.contains(activity)
                Button {
                    if isSelected {
                        selected.remove(activity)
                    } else {
                        selected.insert(activity)
                    }
                } label: {
                    Label(activity.rawValue, systemImage: activity.symbol)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TemplateChipGrid: View {
    let templates: [PackingTemplate]
    @Binding var selected: [PackingTemplate]

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(templates) { template in
                let isSelected = selected.contains { $0.id == template.id }
                Button {
                    if isSelected {
                        selected.removeAll { $0.id == template.id }
                    } else {
                        selected.append(template)
                    }
                } label: {
                    Text(template.name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddTripView()
        .modelContainer(
            for: [
                Trip.self, PackingItem.self, Traveler.self, Pet.self,
                TravelerProfile.self, PetProfile.self, ProfileItem.self, CustomCategory.self,
                PackingTemplate.self, TemplateItem.self,
            ],
            inMemory: true
        )
}
