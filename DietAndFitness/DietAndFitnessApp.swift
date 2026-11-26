import SwiftUI
import SwiftData

@main
struct DietAndFitnessApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Food.self, Ingredient.self, LogEntry.self, Workout.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("didSeedFoods") private var didSeedFoods = false

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Log", systemImage: "fork.knife") }
            FoodsView()
                .tabItem { Label("My Foods", systemImage: "list.bullet") }
            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }
        }
        .task {
            if !didSeedFoods {
                SeedData.insert(into: context)
                didSeedFoods = true
            }
        }
    }
}
