import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            WorkoutDay(day: $day)
                .navigationTitle("Workouts")
                .toolbar {
                    if !Calendar.current.isDateInToday(day) {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Today") { day = Calendar.current.startOfDay(for: .now) }
                        }
                    }
                }
        }
    }
}

private struct WorkoutDay: View {
    @Environment(\.modelContext) private var context
    @Binding var day: Date
    @Query private var workouts: [Workout]
    @State private var showingAdd = false
    @State private var editing: Workout?

    init(day: Binding<Date>) {
        _day = day
        let range = dayRange(day.wrappedValue)
        let start = range.start
        let end = range.end
        _workouts = Query(filter: #Predicate<Workout> { $0.day >= start && $0.day < end },
                          sort: \Workout.createdAt)
    }

    var body: some View {
        List {
            Section { DaySwitcher(day: $day) }

            Section("Exercises") {
                if workouts.isEmpty {
                    Text("No workouts logged.").foregroundStyle(.secondary)
                }
                ForEach(workouts) { workout in
                    Button { editing = workout } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name)
                            if !workout.detail.isEmpty {
                                Text(workout.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(workouts[index]) }
                }
                Button { showingAdd = true } label: {
                    Label("Add exercise", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAdd) { WorkoutEditor(day: Calendar.current.startOfDay(for: day)) }
        .sheet(item: $editing) { workout in WorkoutEditor(day: workout.day, workout: workout) }
    }
}

/// Add or edit an exercise. Everything except the name is optional.
/// Picking an exercise you've done before fills in last time's numbers.
private struct WorkoutEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.createdAt, order: .reverse) private var history: [Workout]

    let day: Date
    let workout: Workout?

    @State private var name = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var minutes = ""
    @State private var notes = ""

    init(day: Date, workout: Workout? = nil) {
        self.day = day
        self.workout = workout
        if let workout {
            _name = State(initialValue: workout.name)
            _sets = State(initialValue: workout.sets.map(String.init) ?? "")
            _reps = State(initialValue: workout.reps.map(String.init) ?? "")
            _weight = State(initialValue: workout.weight?.editText ?? "")
            _minutes = State(initialValue: workout.minutes?.editText ?? "")
            _notes = State(initialValue: workout.notes)
        }
    }

    /// Most recent workout for each distinct exercise name.
    private var pastExercises: [Workout] {
        var seen = Set<String>()
        var result: [Workout] = []
        for item in history where item !== workout {
            let key = item.name.trimmed.lowercased()
            if !key.isEmpty && !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }
        let query = name.trimmed
        return Array(result
            .filter { query.isEmpty || ($0.name.localizedCaseInsensitiveContains(query) && !$0.name.sameName(as: query)) }
            .prefix(8))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise (e.g. Bench press, Run)", text: $name)
                        .textInputAutocapitalization(.words)
                    NumberRow(label: "Sets", text: $sets)
                    NumberRow(label: "Reps", text: $reps)
                    NumberRow(label: "Weight", text: $weight, unit: "lb")
                    NumberRow(label: "Time", text: $minutes, unit: "min")
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                if workout == nil && !pastExercises.isEmpty {
                    Section("Done before") {
                        ForEach(pastExercises) { past in
                            Button { fill(from: past) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(past.name)
                                    if !past.detail.isEmpty {
                                        Text(past.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle(workout == nil ? "Add Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmed.isEmpty)
                }
            }
        }
    }

    private func fill(from past: Workout) {
        name = past.name
        sets = past.sets.map(String.init) ?? ""
        reps = past.reps.map(String.init) ?? ""
        weight = past.weight?.editText ?? ""
        minutes = past.minutes?.editText ?? ""
    }

    private func save() {
        let setCount = parseNumber(sets).map { Int($0) }
        let repCount = parseNumber(reps).map { Int($0) }
        if let workout {
            workout.name = name.trimmed
            workout.sets = setCount
            workout.reps = repCount
            workout.weight = parseNumber(weight)
            workout.minutes = parseNumber(minutes)
            workout.notes = notes.trimmed
        } else {
            context.insert(Workout(day: day, name: name.trimmed, sets: setCount, reps: repCount,
                                   weight: parseNumber(weight), minutes: parseNumber(minutes), notes: notes.trimmed))
        }
        dismiss()
    }
}
