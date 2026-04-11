//
//  Receipe.swift
//  Let him cook
//
//  Created by Anthime Willmann on 17.12.25.
//

import Foundation

struct Recipe: Identifiable {
    let id: UUID
    let title: String
    let ingredients: [String]
    let steps: [String]
    var isPinned: Bool = false
    let createdAt: Date

    init(id: UUID = UUID(), title: String, ingredients: [String] = [], steps: [String], isPinned: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}
