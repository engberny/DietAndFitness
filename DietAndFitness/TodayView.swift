import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            DayLog(day: $day)
                .navigationTitle("Daily Log")
                .toolbar {
                    if !Calendar.current.isDateInToday(day) {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Today") { day = Calendar.current.startOfDay(for: .now) }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    }
                }
                .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}

private struct DayLog: View {
    @Environment(\.modelContext) private var context
    @Binding var day: Date
    @Query private var entries: [LogEntry]
    @State private var showingAdd = false
    @State private var editing: LogEntry?

    init(day: Binding<Date>) {
        _day = day
        let range = dayRange(day.wrappedValue)
        let start = range.start
        let end = range.end
        _entries = Query(filter: #Predicate<LogEntry> { $0.day >= start && $0.day < end },
                         sort: \LogEntry.createdAt)
    }

    private var startOfDay: Date { Calendar.current.startOfDay(for: day) }

    var body: some View {
        List {
            Section { DaySwitcher(day: $day) }

            Section("Summary") {
                DaySummary(total: entries.sumMacros { $0.total })
            }

            Section("Food") {
                if entries.isEmpty {
                    Text("Nothing logged yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    Button { editing = entry } label: { EntryRow(entry: entry) }
                        .tint(.primary)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(entries[index]) }
                }
                Button { showingAdd = true } label: {
                    Label("Add food", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAdd) { EntryEditor(day: startOfDay) }
        .sheet(item: $editing) { entry in EntryEditor(day: startOfDay, entry: entry) }
    }
}

private struct EntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.name)
                Spacer()
                Text("\(entry.total.calories.clean) cal")
                    .foregroundStyle(.secondary)
            }
            Text("\(entry.servings.clean) serving\(entry.servings == 1 ? "" : "s") · P \(entry.total.protein.clean)g · C \(entry.total.carbs.clean)g · F \(entry.total.fat.clean)g")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// The spreadsheet's Summary block: calories, protein against the goal,
/// and how much of the day's calories came from protein, carbs and fat.
private struct DaySummary: View {
    let total: Macros
    @AppStorage("proteinGoal") private var proteinGoal = 180.0
    @AppStorage("calorieGoal") private var calorieGoal = 0.0

    private func share(_ grams: Double, _ caloriesPerGram: Double) -> String {
        guard total.calories > 0 else { return "–" }
        return (grams * caloriesPerGram / total.calories).formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        LabeledContent("Calories") {
            if calorieGoal > 0 {
                Text("\(total.calories.clean) of \(calorieGoal.clean)")
            } else {
                Text(total.calories.clean)
            }
        }
        if calorieGoal > 0 {
            ProgressView(value: min(total.calories / calorieGoal, 1))
        }

        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Protein") {
                Text("\(total.protein.clean)g of \(proteinGoal.clean)g")
            }
            if proteinGoal > 0 {
                ProgressView(value: min(total.protein / proteinGoal, 1))
                Text("\((total.protein / proteinGoal).formatted(.percent.precision(.fractionLength(0)))) of your protein goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        LabeledContent("Carbs", value: "\(total.carbs.clean)g")
        LabeledContent("Fat", value: "\(total.fat.clean)g")

        LabeledContent("Calories from") {
            Text("P \(share(total.protein, Macros.proteinCaloriesPerGram)) · C \(share(total.carbs, Macros.carbCaloriesPerGram)) · F \(share(total.fat, Macros.fatCaloriesPerGram))")
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("proteinGoal") private var proteinGoal = 180.0
    @AppStorage("calorieGoal") private var calorieGoal = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Daily protein goal")
                        Spacer()
                        TextField("180", value: $proteinGoal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("g").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Daily calorie goal")
                        Spacer()
                        TextField("None", value: $calorieGoal, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                        Text("cal").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Leave the calorie goal at 0 to hide it.")
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
