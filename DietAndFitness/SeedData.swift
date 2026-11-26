import Foundation
import SwiftData

/// Starter foods added on first launch. They can be edited or deleted in My Foods.
enum SeedData {
    static func insert(into context: ModelContext) {
        // Stuff, copied from the "Stuff" sheet of the Daily Diet Log spreadsheet.
        let stuffIngredients: [(String, Double, Macros)] = [
            ("Chicken", 4, Macros(calories: 160, protein: 22, carbs: 0.1, fat: 9)),
            ("Beans", 7, Macros(calories: 100, protein: 7, carbs: 19, fat: 0.1)),
            ("Onion", 2, Macros(calories: 44, protein: 1, carbs: 11, fat: 0.1)),
            ("Potatoes", 6, Macros(calories: 80, protein: 2, carbs: 15, fat: 0.1)),
            ("Oil", 5, Macros(calories: 120, protein: 0, carbs: 0, fat: 14)),
        ]

        let stuff = Food(name: "Stuff",
                         servingNote: "whole batch",
                         notes: "1lb Ground Chicken, 2 Cans Black Beans, 2 Onions, 1 Bag Little Duos Potatoes",
                         isHomemade: true)
        context.insert(stuff)
        for (index, item) in stuffIngredients.enumerated() {
            let ingredient = Ingredient(name: item.0, servings: item.1, perServing: item.2, order: index)
            context.insert(ingredient)
            stuff.ingredients.append(ingredient)
        }
        stuff.macros = stuffIngredients.sumMacros { $0.2.times($0.1) }

        // The same ingredients as plain foods, so they are quick to reuse in new meals.
        for item in stuffIngredients {
            context.insert(Food(name: item.0, servingNote: "1 serving", macros: item.2))
        }

        // Common foods. Typical label values; edit them to match what you buy.
        context.insert(Food(name: "Milk", servingNote: "1 cup, 2%",
                            macros: Macros(calories: 122, protein: 8, carbs: 12, fat: 4.8)))
        context.insert(Food(name: "Eggs", servingNote: "1 large egg",
                            macros: Macros(calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8)))
    }
}
