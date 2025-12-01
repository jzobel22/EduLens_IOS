# EduLens Student iOS App (Skeleton)

This folder contains a SwiftUI-based iOS app skeleton for the EduLens **student** experience.

## How to use

1. In Xcode, create a new **iOS App** project (Swift + SwiftUI) called `EduLensStudentApp`.
2. Close Xcode.
3. Replace the generated `App` / `ContentView` files with the contents of:
   - `App/AppState.swift`
   - `App/Config.swift`
   - `Views/EduLensStudentApp.swift`
   - `Views/RootView.swift`
   - `Views/*.swift`
   - `Models/*.swift`
   - `Services/*.swift`
4. Re-open the project in Xcode and build/run.

Point `BACKEND_BASE_URL` in `App/Config.swift` at the same backend URL your WebUI uses.
