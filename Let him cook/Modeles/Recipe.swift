//
//  Receipe.swift
//  Let him cook
//
//  Created by Anthime Willmann on 17.12.25.
//

import Foundation

struct Recipe: Identifiable {
    let id = UUID()
    let title: String
    let steps: [String]
}
