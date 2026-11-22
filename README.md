# perkakasku-mobile-ios

Native SwiftUI iOS client for **Perkakasku** — a privacy-first document, image, and utility studio featuring **21 tools** with a warm architectural design system (**Warm Alabaster** light theme / **Obsidian Espresso** dark theme and **Signal Orange** accents).

Built natively with Apple frameworks (`SwiftUI`, `PDFKit`, `Vision`, `CoreImage`, `PencilKit`, `PhotosUI`, `QuickLook`, `SwiftData`) — no WebView, React Native, or Flutter wrappers.

---

## Key Capabilities

- **Immediate Guest Studio Access:** Launches directly through an animated splash sequence into the main 5-tab workspace without requiring sign-in (`AuthService` & `AuthView` are preserved in source for future account opt-in).
- **On-Device First Privacy:** 15 of 21 workflows execute completely offline inside the iOS sandbox (`PDFKit`, Apple `Vision` OCR & foreground segmentation, `CoreImage`, `ImageIO`, `PencilKit`, CoreGraphics vector PDF composition).
- **Optional Perkakasku Sandbox Backend:** Connects cleanly to local Docker (`http://127.0.0.1:4000`) or `https://perkakasku.cloud` (configurable in **Settings**) for format conversion endpoints (`/api/tools/pdf-compress`, `/api/tools/pdf-to-word`, `/api/tools/pdf-to-excel`, `/api/tools/word-to-pdf`, `/api/tools/passport-photo`, `/api/tools/heic-to-jpg`). No API keys or backend secrets are bundled in this repository.

---

## Tool Suite (21 Registered Tools)

| Category | Tools | Execution Engine |
|---|---|---|
| **PDF Suite (10)** | Compress PDF, Merge PDF, Split PDF, PDF to Image, PDF to Excel, PDF to Word, PDF Signature, PDF Password Protection, PDF Watermark, Image to PDF | Local (`PDFKit`, `PencilKit`, `CoreGraphics`, `ZIPBuilder`) + Server Sandbox for Compress/Word/Excel |
| **Image Studio (6)** | Compress Image, Resize & Convert, Remove Background, Passport Photo Maker (`2x3`/`3x4`/`4x6` @ 300 DPI), Crop Image, HEIC to JPG | Local (`Vision`, `CoreImage`, `ImageIO`) + optional Server DPI/HEIC |
| **Documents & Utilities (5)** | QR Code Generator (PNG + SVG), Word Counter, OCR Text Recognition (`id-ID` + `en-US`), Word to PDF (`.docx`), JSON Formatter/Validator/Diff | Local (`Vision` OCR, `CoreImage`, native Swift) + Server `.docx`→PDF |

---

## Requirements & Project Structure

- **Xcode:** Xcode 16+ / Swift 6.0 (built & tested with Xcode 27.1 / iOS Simulator SDK)
- **Deployment Target:** iOS 26.0+ · Bundle ID: `cloud.perkakasku.ios`
- **External Dependencies:** None (zero third-party CocoaPods/SPM packages)

```text
perkakasku-mobile-ios/
├── Perkakasku.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/Perkakasku.xcscheme
└── Perkakasku/
    ├── App/            # PerkakaskuApp, RootView, SplashView
    ├── Core/           # DesignSystem/Theme, Networking, Security, Storage, Utilities, Extensions
    ├── Models/         # Tool, BackendModels, ProcessedItem, AuthResponse
    ├── Services/       # APIService, AuthService, PDFService, ImageService, VisionOCRService, VisionSegmentationService, HistoryService, FavoritesService, AppSettingsService
    ├── Components/     # FileImportButton, PhotoImportButton, ExportButton, QuickLook & ToolWorkspaceComponents
    ├── Features/       # Home, Tools (21-slug Router + Detail), PDF, Images, Documents, History, Favorites, Premium, Settings
    ├── Resources/      # Info.plist, Perkakasku.entitlements
    ├── PerkakaskuTests/
    └── PerkakaskuUITests/
```

---

## Build & Run Locally

1. Clone this repository and open `Perkakasku.xcodeproj` in Xcode:
   ```bash
   git clone https://github.com/randisumitro/perkakasku-mobile-ios.git
   cd perkakasku-mobile-ios
   open Perkakasku.xcodeproj
   ```
2. Optional — start the Perkakasku backend locally (from the main `perkakasku` repository) so server-backed converters (`http://127.0.0.1:4000`) are reachable from the iOS Simulator, or switch/override the endpoint URL in **Settings → Docker & Cloud Sandbox**.
3. Run tests or build via CLI:
   ```bash
   xcodebuild clean test \
     -project Perkakasku.xcodeproj \
     -scheme Perkakasku \
     -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
     CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
   ```

---

## Security Note

This public repository contains client source code only. All authentication tokens generated at runtime stay inside the user's iOS Keychain (`KeychainHelper`), and no server environment files, API keys, signing certificates, or provisioning profiles are included.
