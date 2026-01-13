//
//  RecipeStore.swift
//  Let him cook
//
//  Created by Anthime Willmann on 17.12.25.
//

import SwiftUI

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = [
        Recipe(
            title: "Pasta Aglio e Olio",
            steps: [
                "Wasser aufsetzen und salzen",
                "Knoblauch schneiden",
                "Pasta kochen",
                "Knoblauch in Öl anbraten",
                "Alles vermengen und servieren"
            ]
        )
    ]
}
