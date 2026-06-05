# Decaf
Keep your mac awake without caffeinate

Decaf is a native macOS menu bar app for managing `/usr/bin/caffeinate`.

## Run From Terminal
Open this folder in Xcode and run the `Decaf` executable target, or use:

```sh
swift run Decaf
```

## Build A Finder-Launchable App

Build the release app bundle with:

```sh
./scripts/build-app.sh
```

The app will be created at:

```sh
dist/Decaf.app
```

You can launch that app from Finder without keeping Terminal open. Move `dist/Decaf.app` to `/Applications` if you want it installed like a normal menu bar utility.

The script prepares icon assets, builds a universal release binary, creates the `.app` bundle, adds the required app metadata, and ad-hoc signs it for local use.

## Xcode Project And Icon Assets

`Decaf.xcodeproj` is included for a proper macOS app target. It uses:

```sh
Resources/Assets.xcassets/AppIcon.appiconset
```

The selected icon source is:

```sh
Resources/IconSources/decaf-selected-bottom-left.png
```

Regenerate the asset catalog and `.icns` fallback with:

```sh
swift scripts/prepare-app-icons.swift
```

Apple's current Liquid Glass multi-appearance icon workflow uses Icon Composer. This repo now has the Xcode app target and asset catalog foundation; a future `AppIcon.icon` Icon Composer file can replace the asset catalog when the tool is available locally.

The app targets macOS 13+ and uses SwiftUI `MenuBarExtra`.


"Licensed under AGPLv3. See LICENSE and CONTRIBUTING.md for details."
