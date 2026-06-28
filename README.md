# Quran App for iOS

Source code for an iOS Quran, prayer-times, widgets, Live Activity, and Apple Watch app.

## Project

- Main app: `QuranApp`
- iOS widgets: `QuranWidget`
- Apple Watch app: `QuranWatch`
- Watch complications/widgets: `QuranWatchWidget`
- Bundle identifier used by the original app: `tech.meshari.QuranApp`
- Public release prepared from app version `1.8` build `9`

## Requirements

- Latest Xcode with iOS and watchOS SDKs
- Apple Developer account for device builds, push notifications, widgets, and watch targets

## Run

```sh
open QuranApp.xcodeproj
```

In Xcode, choose your Apple Developer Team and update bundle identifiers if you are building under your own account.

## What is intentionally not included

- Apple signing certificates, provisioning profiles, App Store Connect API keys, and private environment files
- Local Android files, import scripts, server upload scripts, SQL dumps, and generated build output
- Large private data dumps that are not required for the iOS source release

## Rights

The Swift source code in this repository is licensed under the MIT License. Quran text, audio, fonts, and any third-party content or assets remain subject to their original rights and licenses.
