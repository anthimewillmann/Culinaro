# Culinaro

**A native SwiftUI cooking app with on-device AI, recipes and lessons, shopping lists, nutrition tracking, and iCloud sync.**

<p align="left">
  <a href="https://apps.apple.com/us/app/culinaro/id6764299394">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg"
         alt="Download on the App Store"
         height="60">
  </a>
</p>

Culinaro helps you collect recipes, learn cooking techniques, prepare shopping lists, and follow instructions step by step on iPhone and iPad. Create content manually, generate it from an idea with Apple Foundation Models, or scan it from a photo. Track nutrition and cooking progress, and compare your score with Game Center friends.

> A personal iOS portfolio project exploring SwiftUI, on-device AI, Vision OCR, CloudKit, GameKit, and custom animated interfaces.

## Highlights

- Five tabs: Recipes, Lessons, Shopping, Nutrition, and Overview
- Manual creation and editing of recipes and cooking lessons
- AI generation, photo scanning, and automatic categorization
- Pinning and bulk actions for recipes and lessons
- Guided cooking and learning mode with optional AI tips
- Shopping lists populated manually, from photos, or from recipe and lesson ingredients
- Editable nutrition values, AI estimates, and meal logging
- Daily nutrition totals, seven-day averages, and a thirty-day calorie average
- Cooking streaks, activity statistics, and a Game Center friends leaderboard
- PDF sharing for individual recipes and lessons or selected collections
- Local persistence with private iCloud synchronization
- Animated meadow and cooking backgrounds with separate animation controls
- Localized interface with 22 locale entries in the main String Catalog

## Screenshots

<p align="center">
  <img src="Screenshots/culinaro-recipes.png" width="30%" alt="Recipes with pinned favorites and AI categories"/>
  <img src="Screenshots/culinaro-new-recipe.png" width="30%" alt="Recipe editor with AI generation and photo scanning"/>
  <img src="Screenshots/culinaro-ingredients.png" width="30%" alt="Ingredient overview before cooking"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-lessons.png" width="30%" alt="Cooking lessons grouped by technique"/>
  <img src="Screenshots/culinaro-shopping.png" width="30%" alt="Shopping list with ingredients grouped by category"/>
  <img src="Screenshots/culinaro-nutrition.png" width="30%" alt="Nutrition totals and daily averages"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-overview.png" width="30%" alt="Overview with streak, statistics, friends, and animation settings"/>
  <img src="Screenshots/culinaro-step-1.jpeg" width="30%" alt="Cooking step 1 with a practical AI tip"/>
  <img src="Screenshots/culinaro-step-3.jpeg" width="30%" alt="Cooking step 3 with an animated background"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-step-5.jpeg" width="30%" alt="Cooking step 5 with a serving instruction"/>
  <img src="Screenshots/culinaro-enjoy.jpeg" width="30%" alt="Enjoy screen at the end of cooking"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-ipad-recipes.jpeg" width="46%" alt="iPad recipes with pinned favorites and categories"/>
  <img src="Screenshots/culinaro-ipad-edit-recipe.jpeg" width="46%" alt="iPad recipe editor with AI generation and photo scanning"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-ipad-ingredients.jpeg" width="46%" alt="iPad ingredient and nutrition overview before cooking"/>
  <img src="Screenshots/culinaro-ipad-lessons.jpeg" width="46%" alt="iPad cooking lessons grouped by technique"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-ipad-shopping.jpeg" width="46%" alt="iPad shopping list with ingredients grouped by category"/>
  <img src="Screenshots/culinaro-ipad-nutrition.jpeg" width="46%" alt="iPad nutrition totals and daily averages"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-ipad-overview.jpeg" width="46%" alt="iPad overview with streak, statistics, friends, and animation settings"/>
  <img src="Screenshots/culinaro-ipad-step-1.jpeg" width="46%" alt="iPad cooking step 1 with a practical AI tip"/>
</p>

<p align="center">
  <img src="Screenshots/culinaro-ipad-step-3.jpeg" width="46%" alt="iPad cooking step 3 with an animated background"/>
  <img src="Screenshots/culinaro-ipad-step-5.jpeg" width="46%" alt="iPad cooking step 5 with a serving instruction"/>
</p>

### Figma Designs

<p align="center">
  <img src="Screenshots/culinaro-figma-add-recipe.png" width="49%" alt="Culinaro add-recipe flow prototype in Figma"/>
  <img src="Screenshots/culinaro-figma-recipe-flow.png" width="49%" alt="Culinaro recipe cooking flow prototype in Figma"/>
</p>

## Features

### Recipes and Cooking Lessons

Recipes and lessons share an editor for titles, ingredients or tools, preparation or teaching steps, nutrition values, and the AI-tip preference. Both can be created manually, generated from a prompt, or extracted from camera and photo-library images.

Pinned items appear above AI-generated categories. Select multiple items to add their ingredients to the shopping list, log nutrition, export a PDF collection, or delete them. Individual items can also be edited, pinned, shared, and opened in the guided cooking interface.

### On-Device AI and Scanning

`RecipeAIService` uses Apple Foundation Models for structured recipe and lesson generation, shopping-list extraction, nutrition estimates, short cooking tips, and category assignments. Vision recognizes text in photos before Foundation Models converts it into structured content. Generated and scanned content can be reviewed and edited before saving.

`AILanguageResolver` detects the language of typed generation prompts when confidence is sufficient. Other requests use the app language, with system-language and English fallbacks. Model locale support is checked, and OCR prioritizes the resolved language alongside German and English.

Notes entered in Overview are passed to recipe generation as allergy or intolerance constraints. They do not provide a verified allergen check.

### Guided Cooking and Learning

The shared cooking mode starts with an ingredient and nutrition overview, then presents one instruction at a time. Optional AI tips are cached in memory during the session. Missing nutrition values can be estimated and saved back to the recipe or lesson. Completing the final step records progress and contributes to the cooking streak.

The interface switches between custom meadow and cooking animations. Each animation can be enabled or disabled in Overview, and those preferences persist locally.

### Shopping Lists

Add ingredients manually with optional quantities, import them from recipes or lessons, or scan a printed or handwritten list. Imported ingredients retain their source title. AI groups items into categories, and items can be removed as shopping progresses.

### Nutrition

Recipes and lessons can store calories, protein, carbohydrates, fat, and a serving count. Nutrition values can be entered manually or estimated by AI. Log meals from saved content or create a nutrition entry through the Nutrition tab, including from a photo or generated recipe.

The dashboard shows today's calories and macronutrients, daily averages over the last seven days, and average daily calories over the last thirty days. AI-generated nutrition values are approximate.

### Progress and Sharing

Overview shows created recipes and lessons, completed cooking sessions and lessons, and the current daily streak. The Game Center score is the sum of created recipes, created lessons, completed cooking sessions, and completed lessons. Authenticated players can view a friends leaderboard.

Recipes and lessons can be shared as PDFs through the system share sheet, individually or as a selected collection.

## Storage and Synchronization

Recipes, lessons, shopping-list items, and logged meals are cached locally as Codable JSON in UserDefaults. Their stores load the cache immediately, fetch remote records on initialization, and upload changes to the user's private CloudKit database. Recipe, lesson, and shopping-list screens also support pull-to-refresh.

Statistics, creation counters, notes, and animation preferences remain local. Game Center receives the aggregate score separately.

Cloud synchronization currently uses direct record fetches, saves, and deletes with in-memory tracking of pending changes. It does not include a durable offline retry queue or a full cross-device conflict-resolution system.

## Tech Stack

| Area | Technology |
|---|---|
| Language and UI | Swift, SwiftUI |
| AI and structured output | Apple Foundation Models, `@Generable` |
| Language detection | NaturalLanguage |
| Text recognition | Vision |
| Photo import and camera | PhotosUI, UIKit `UIImagePickerController` |
| State | Combine `ObservableObject` / `@Published`, Observation `@Observable`, SwiftUI state |
| Local persistence | UserDefaults, Codable JSON |
| Cloud synchronization | CloudKit private database |
| Friends leaderboard | GameKit / Game Center |
| PDF sharing | SwiftUI `ImageRenderer`, Core Graphics, `Transferable`, `ShareLink` |
| Localization | Xcode String Catalogs |
| Build | Xcode project and shared `Culinaro` scheme |

The project has no third-party package dependencies or custom backend. CloudKit and Game Center provide its online services.

## Project Structure

```text
Culinaro/
├── CulinaroApp.swift             App entry point and dependency injection
├── ContentView.swift             Five-tab navigation and shared state
├── Models/
│   ├── Recipe.swift, Lesson.swift, Cookable.swift
│   ├── ShoppingListItem.swift, NutritionInfo.swift, LoggedMeal.swift
│   ├── RecipeAIService.swift     Generation, OCR parsing, tips, nutrition, categories
│   ├── AIModels.swift            Structured Foundation Models output types
│   ├── AILanguageResolver.swift  AI and OCR language selection
│   ├── CloudKitManager.swift     Private CloudKit database operations
│   ├── CloudKitConversions.swift Model-to-record mapping
│   └── GameCenterManager.swift   Authentication, scores, friends leaderboard
├── Stores/                      Recipes, lessons, shopping, nutrition, statistics
├── Views/
│   ├── Recipes/                 Tab screens and shared content editor
│   ├── CookMode/                Guided cooking and learning interface
│   └── Shared/                  PDF export, camera, backgrounds, reusable views
├── Localizable.xcstrings         Interface translations
├── Culinaro-InfoPlist.xcstrings   Localized app metadata
└── Culinaro.entitlements         iCloud, Game Center, and push entitlements
```

## Requirements

- macOS with Xcode and an iOS 26 SDK capable of building the project
- iPhone or iPad running iOS/iPadOS 26.0 or later, as configured on the app target
- A device and configuration supporting Apple Foundation Models for AI features
- Camera access for taking recipe or shopping-list photos
- An iCloud account and configured CloudKit container for synchronization
- Game Center authentication and a configured leaderboard for friends scores

The app target overrides the project-level iOS 26.1 setting with iOS 26.0. The repository does not specify an exact minimum Xcode patch version. AI availability is separate from the deployment target; a successful build does not establish that AI features are available on the selected device or simulator.

## Getting Started

```bash
git clone https://github.com/anthimewillmann/Culinaro.git
cd Culinaro
open Culinaro.xcodeproj
```

1. Select the shared `Culinaro` scheme and an iPhone or iPad destination.
2. Set your development team and signing configuration. For your own app, use a bundle identifier registered to your team.
3. Configure the target's iCloud/CloudKit and Game Center capabilities for your Apple developer account. Keep the entitlements and provisioning configuration consistent.
4. Configure a CloudKit container and the record types used in `CloudKitConversions.swift`: `Recipe`, `Lesson`, `ShoppingListItem`, and `LoggedMeal`.
5. Configure the Game Center leaderboard in App Store Connect. The source currently uses the identifier `culinaro_total_score`.
6. Build and run in Xcode. Use a compatible device to exercise AI, camera, iCloud, and Game Center features.

The checked-in app uses bundle identifier `com.anthimewillmann.culinaro.app` and CloudKit container `iCloud.com.anthimewillmann.culinaro.app`. A fork needs access to these resources or its own configuration. No API keys or third-party dependency installation are required.

For a simulator compilation without device signing:

```bash
xcodebuild \
  -project Culinaro.xcodeproj \
  -scheme Culinaro \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Current Status and Limitations

The Xcode project currently declares version **3.0.2**, build **12**. This describes the repository configuration, not necessarily the current App Store release.

- No automated unit/UI tests or CI/CD workflow are included.
- There is no dedicated Foundation Models availability screen or complete non-AI fallback. Some failed generation, scanning, or categorization requests can leave a loading indicator visible.
- Cloud sync has no durable retry queue, persistent deletion markers, or comprehensive conflict resolution. Local statistics and preferences are not synchronized.
- The current recipe and lesson lists use categories and pinning; they do not include a search field.
- Scanned images and raw OCR text are not retained by the app; cooking tips are not persisted between sessions.
- UserDefaults persistence has no explicit schema migration layer.
- Meal planning and editable recipe-file import are not implemented; sharing is through PDF export.

## Privacy

AI generation and image text recognition use Apple's on-device frameworks. The app does not include a custom backend, analytics SDK, or third-party tracking integration.

Saved recipes, lessons, shopping-list items, and meal logs are stored locally and sent to the user's private CloudKit database when synchronization succeeds. Game Center handles player authentication, score submission, and friends leaderboard data. Notes and animation preferences are stored locally; recipe generation uses the notes on device.

Imported images and raw OCR text are processed without being saved by the app. PDF sharing sends the selected content to the destination the user chooses in the share sheet.

## License

No `LICENSE` file is currently included in this repository.
