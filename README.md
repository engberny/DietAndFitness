# Diet Log (DietAndFitness)

A simple iPhone app for logging what you eat and your workouts, modeled on the Daily Diet Log spreadsheet.

## What it does

- **Log tab**: one list per day. Add a food with its servings. Calories, protein, carbs and fat are optional,
  and picking a saved food (Milk, Eggs, Stuff…) fills them in. The summary shows calories, protein against
  your goal (180 g by default, change it with the gear button), carbs, fat, and the share of calories from each.
- **My Foods tab**: saved foods and homemade meals. A homemade meal can list its ingredients (like the
  Stuff sheet) and its totals add up automatically, or you can type the totals directly. One serving of a
  homemade meal is the whole batch, so a quarter of it is logged as 0.25 servings.
- **Workouts tab**: exercises per day with optional sets, reps, weight, time and notes.

Data stays on the phone (SwiftData). On first launch the app adds Stuff (with its ingredients), Milk and Eggs.

## Run it

Needs a Mac with Xcode 16 or later, and iOS 17 or later on the phone.

1. Open `DietAndFitness.xcodeproj` in Xcode.
2. Choose the DietAndFitness target > Signing & Capabilities, and pick your Apple ID as the Team
   (a free account works; the app then needs reinstalling every 7 days).
3. Plug in your iPhone (turn on Developer Mode in Settings > Privacy & Security if asked), select it, and press Run.

## No Mac? Use TestFlight

GitHub Actions can build and upload the app to TestFlight for you. Follow [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).
Every push also runs a quick "Build check" to make sure the app still compiles.
