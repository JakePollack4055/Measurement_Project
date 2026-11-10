# OrientationCamera

Native SwiftUI iPhone camera app that records compass heading and device attitude with each photo.

## Windows workflow

1. Install Git and VS Code on Windows.
2. Open this folder in VS Code.
3. Push it to a GitHub repository.
4. GitHub Actions runs on a macOS runner and generates the Xcode project with XcodeGen.

The first workflow builds the app for the iOS Simulator. Device installation and TestFlight distribution require Apple signing credentials and an Apple Developer account.

## Local macOS setup

If you later use a Mac, install XcodeGen and run:

```bash
brew install xcodegen
xcodegen generate
open OrientationCamera.xcodeproj
```

## Required permissions

The app requests camera, motion, and photo-library access in `Info.plist`.

