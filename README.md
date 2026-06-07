# Culinaro

**A native SwiftUI recipe app with on-device AI, photo scanning, and a guided cooking mode.**

<p align="left">
  <a href="https://apps.apple.com/us/app/culinaro/id6764299394">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg"
         alt="Download on the App Store"
         height="60">
  </a>
</p>

Culinaro helps you collect, create, scan, and cook recipes on iPhone and iPad. Recipes are stored locally, can be generated from a simple dish idea, extracted from photos using OCR, and followed step by step in a focused cooking interface.

> Built as a personal iOS portfolio project exploring SwiftUI, Apple Foundation Models, Vision OCR, local-first app architecture, and polished mobile interaction design.

## Highlights

- Local recipe collection
- Manual recipe creation and editing
- AI-generated recipes from a dish name
- Recipe scanning from camera or photo library
- Vision OCR plus structured Foundation Models output
- Search by recipe title
- Pinning for frequently used recipes
- Guided step-by-step cooking mode
- Optional AI cooking tips per step
- Animated SwiftUI cooking background
- iPhone and iPad support
- Localized UI via Xcode String Catalog

## Screenshots

Add screenshots from the `Screenshots/` folder here:

```markdown
<p align="center">
  <img src="Screenshots/4.jpg" width="220" />
  <img src="Screenshots/5.jpg" width="220" />
  <img src="Screenshots/7.jpg" width="220" />
</p>
```

Recommended screenshot flow:

1. Recipe list with search and pinned recipes
2. AI-generated recipe form
3. Ingredients overview
4. Cooking step view
5. Final “Enjoy!” screen

## How It Works

```text
Recipe idea
   |
   v
Foundation Models
   |
   v
Structured recipe
   |
   v
Editable form
   |
   v
Local storage
```

Photo import flow:

```text
Camera / Photo Library
   |
   v
Vision OCR
   |
   v
Raw recipe text
   |
   v
Foundation Models
   |
   v
Title + ingredients + steps
```

Cooking flow:

```text
Saved recipe
   |
   v
Ingredients overview
   |
   v
Step 1 -> Step 2 -> Step 3
   |
   v
Optional AI tip per step
   |
   v
Enjoy!
```

## Tech Stack

| Area | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| AI | Apple Foundation Models |
| OCR | Vision |
| Photos | PhotosUI |
| Camera | UIKit `UIImagePickerController` |
| State | ObservableObject, `@Published`, SwiftUI state |
| Persistence | UserDefaults + Codable JSON |
| Localization | Xcode String Catalog |
| Build | Xcode project |

Culinaro has no third-party dependencies and no backend in this repository.

## Architecture

Culinaro is a local-first SwiftUI app with a small Store/Service architecture.

```text
+--------------------------------------------------+
|                    SwiftUI App                    |
|                                                  |
|  CulinaroApp -> ContentView -> RecipesView        |
|                              |                   |
|                 +------------+------------+      |
|                 |                         |      |
|          AddRecipeView              CookModeView |
|                 |                         |      |
|          RecipeAIService              Tip Cache  |
|                 |                                |
|       +---------+----------+                     |
|       |                    |                     |
|  Foundation Models      Vision OCR               |
|                                                  |
|              RecipeStore                         |
|                  |                               |
|          UserDefaults / JSON                     |
+--------------------------------------------------+
```

Core components:

```text
CulinaroApp.swift              App entry point
ContentView.swift              Root navigation
Models/Recipe.swift            Persistent recipe model
Stores/RecipeStore.swift       Local recipe state and persistence
Models/RecipeAIService.swift   AI generation, OCR parsing, cooking tips
Views/Recipes                  Recipe list and recipe editor
Views/CookMode                 Guided cooking UI and animation
Localizable.xcstrings          Localized interface strings
```

## Features

### Local Recipe Management

Recipes are stored locally as Codable JSON in UserDefaults. Each recipe contains:

- title
- ingredients
- preparation steps
- pinned state
- AI-tip preference
- generated/manual marker
- creation date

### AI Recipe Generation

Enter a dish name, enable generation, and Culinaro uses Apple Foundation Models to produce a structured recipe with title, ingredients, and steps.

The generated result is inserted into an editable form before saving.

### Recipe Scanning

Culinaro can import recipes from the camera or photo library.

The image is processed with Vision OCR, then the recognized text is transformed into a structured recipe using Foundation Models.

### Guided Cooking Mode

The cooking mode starts with an ingredients overview and then walks through each step one at a time. Optional AI tips can provide short, practical guidance for the current step.

### Animated Cooking Interface

The cooking mode includes a custom SwiftUI background animation built from shapes, masks, transitions, and procedural layout rather than video assets.

## Requirements

- macOS with a compatible full Xcode installation
- iOS 26.1 deployment target
- iPhone or iPad target
- Apple Foundation Models support
- Camera and photo library permissions for scanning/import

The exact minimum Xcode patch version and Foundation Models device availability are not documented in this repository.

## Installation

```bash
git clone https://github.com/anthimewillmann/Culinaro.git
cd Culinaro
open Culinaro.xcodeproj
```

Then in Xcode:

1. Select the `Culinaro` scheme.
2. Choose a compatible iPhone or iPad simulator/device.
3. Configure your own signing team if needed.
4. Build and run.

## Build

From Xcode:

```text
Product -> Build
Product -> Run
```

Possible CLI build:

```bash
xcodebuild \
  -project Culinaro.xcodeproj \
  -scheme Culinaro \
  -configuration Debug \
  build
```

## Current Status

The repository currently contains:

- SwiftUI app source
- Xcode project
- shared scheme
- localized String Catalog
- app icon assets
- screenshots
- README documentation

Not currently included:

- unit tests
- UI tests
- CI/CD pipeline
- SwiftLint or SwiftFormat config
- backend code
- cloud sync
- third-party dependencies
- license file, despite the README mentioning MIT

## Known Limitations

- Local-only storage
- No user accounts
- No cloud synchronization
- No shopping list generation
- No meal planning
- No recipe sharing
- Search only covers recipe titles
- OCR is configured for German and English
- No persisted scanned images
- No persisted AI cooking tips
- No automated tests
- No CI/CD pipeline
- No explicit Foundation Models availability fallback
- UserDefaults storage has no schema migration layer

## Roadmap Ideas

- Cloud synchronization
- User authentication
- Meal planning
- Shopping list generation
- Recipe sharing
- Full-text recipe search
- Tests and CI
- Foundation Models availability fallback
- More robust local persistence
- Reduce Motion support for the cooking animation
- Privacy manifest and clearer privacy documentation

## Privacy

Culinaro is designed as a local-first app. The repository does not contain a backend, analytics integration, tracking SDK, or third-party service integration.

Recipes are stored locally on device. Imported images and OCR text are not persisted by the app according to the current code.

## License

The existing README references MIT, but this repository does not currently include a `LICENSE` file. Add one before displaying a license badge or relying on MIT licensing.
