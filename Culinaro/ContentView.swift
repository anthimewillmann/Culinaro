//
//  ContentView.swift
//  Let him cook
//
//  Created by Anthime Willmann on 16.12.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = RecipeStore()

    var body: some View {
        NavigationStack {
            RecipesView()
        }
        .environmentObject(store)
    }
}
