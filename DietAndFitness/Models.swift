import Foundation
import SwiftData

/// Calories, protein, carbs and fat: the same four numbers as the spreadsheet.
struct Macros: Equatable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static let proteinCaloriesPerGram = 4.0
    static let carbCaloriesPerGram = 4.0
    static let fatCaloriesPerGram = 9.0

    static func + (a: Macros, b: Macros) -> Macros {
        Macros(calories: a.calories + b.calories,
               protein: a.protein + b.protein,
               carbs: a.carbs + b.carbs,
               fat: a.fat + b.fat)
    }

    func times(_ factor: Double) -> Macros {
        Macros(calories: calories * factor,
               protein: protein * factor,
               carbs: carbs * factor,
               fat: fat * factor)
    }

    var summary: String {
        "\(calories.clean) cal · P \(protein.clean)g · C \(carbs.clean)g · F \(fat.clean)g"
    }
}

extension Sequence {
    func sumMacros(_ macros: (Element) -> Macros) -> Macros {
        reduce(Macros()) { $0 + macros($1) }
    }
}

/// A saved food (milk, eggs) or a homemade meal (Stuff) that can be picked in the daily log.
/// The four numbers are per serving. For a homemade meal, one serving is the whole batch,
/// just like the Stuff sheet, so eating a quarter of it is logged as 0.25 servings.
@Model
final class Food {
    var name: String
    var servingNote: String
    var notes: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var isHomemade: Bool
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.meal)
    var ingredients: [Ingredient] = []

    init(name: String, servingNote: String = "", notes: String = "", macros: Macros = Macros(), isHomemade: Bool = false) {
        self.name = name
        self.servingNote = servingNote
        self.notes = notes
        self.calories = macros.calories
        self.protein = macros.protein
        self.carbs = macros.carbs
        self.fat = macros.fat
        self.isHomemade = isHomemade
    }

    var macros: Macros {
        get { Macros(calories: calories, protein: protein, carbs: carbs, fat: fat) }
        set {
            calories = newValue.calories
            protein = newValue.protein
            carbs = newValue.carbs
            fat = newValue.fat
        }
    }

    var sortedIngredients: [Ingredient] {
        ingredients.sorted { $0.order < $1.order }
    }
}

/// One line of a homemade meal, like "Chicken, 4 servings" on the Stuff sheet.
@Model
final class Ingredient {
    var name: String
    var servings: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var order: Int
    var meal: Food?

    init(name: String, servings: Double, perServing: Macros, order: Int) {
        self.name = name
        self.servings = servings
        self.calories = perServing.calories
        self.protein = perServing.protein
        self.carbs = perServing.carbs
        self.fat = perServing.fat
        self.order = order
    }

    var perServing: Macros {
        Macros(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}

/// One row of the daily log. The numbers are copied from the food when it is picked,
/// so editing or deleting a saved food later never changes past days.
@Model
final class LogEntry {
    var day: Date
    var createdAt: Date
    var name: String
    var servings: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(day: Date, name: String, servings: Double, perServing: Macros) {
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.name = name
        self.servings = servings
        self.calories = perServing.calories
        self.protein = perServing.protein
        self.carbs = perServing.carbs
        self.fat = perServing.fat
    }

    var perServing: Macros {
        get { Macros(calories: calories, protein: protein, carbs: carbs, fat: fat) }
        set {
            calories = newValue.calories
            protein = newValue.protein
            carbs = newValue.carbs
            fat = newValue.fat
        }
    }

    var total: Macros { perServing.times(servings) }
}

/// A simple workout entry: an exercise with optional sets, reps, weight and minutes.
@Model
final class Workout {
    var day: Date
    var createdAt: Date
    var name: String
    var sets: Int?
    var reps: Int?
    var weight: Double?
    var minutes: Double?
    var notes: String

    init(day: Date, name: String, sets: Int? = nil, reps: Int? = nil, weight: Double? = nil, minutes: Double? = nil, notes: String = "") {
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.minutes = minutes
        self.notes = notes
    }

    var detail: String {
        var parts: [String] = []
        if let sets, let reps { parts.append("\(sets) × \(reps)") }
        else if let sets { parts.append("\(sets) sets") }
        else if let reps { parts.append("\(reps) reps") }
        if let weight { parts.append("\(weight.clean) lb") }
        if let minutes { parts.append("\(minutes.clean) min") }
        if !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }
}
