//
//  RecipeStore.swift
//  Let him cook
//
//  Created by Anthime Willmann on 17.12.25.
//

import SwiftUI
import Combine

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = [
        Recipe(
            title: "Pasta Aglio e Olio",
            ingredients: ["Pasta", "Knoblauch", "Olivenöl", "Chili", "Petersilie"],
            steps: [
                "Wasser aufsetzen und salzen",
                "Knoblauch schneiden",
                "Pasta kochen",
                "Knoblauch in Öl anbraten",
                "Alles vermengen und servieren"
            ]
        )
    ]

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
    }

    func togglePin(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index] = Recipe(
            id: recipe.id,
            title: recipe.title,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            isPinned: !recipe.isPinned,
            createdAt: recipe.createdAt
        )
    }
}
