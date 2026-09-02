# 📱 ZIPr — Encrypted Mixed-Media Document Viewer & Compressor

**ZIPr** is an advanced Flutter application that combines photos and videos into a single compressed, optionally **AES-256 encrypted** `.zipr` archive container, saves them into a dedicated `/Documents/ZIPr` directory on your device, and renders them in a continuous **PDF-like mixed-media scrollable feed** with multi-touch **pinch-to-zoom and pan for both photos and playing videos**.

---

## 🌟 Key Features

1. **Mixed-Media PDF-Style Feed**:
   - Continuous vertical scroll through photos and playing videos in sequence.
   - Smooth layout with page counter badges, media type indicators (`PHOTO` vs `VIDEO`), and formatted captions.
2. **Double Pinch-to-Zoom Engine**:
   - Built with Flutter's `InteractiveViewer` with multi-touch zoom and panning (up to 5x-6x magnification) for both high-resolution photos and live video playback.
3. **Advanced Media Compression**:
   - Converts photos to optimized **WebP** format (saving up to 75% file size).
   - Transcodes and scales videos with configurable bitrate and resolution presets (Low, Medium, High).
   - Real-time progress tracking with percentage and stage status.
4. **AES-256 Container Encryption**:
   - Optional password protection using AES-256-CBC with PBKDF2/SHA-256 key derivation and random salt/IV generation.
   - Password verification with instant feedback on unlock.
5. **Dedicated `/Documents/ZIPr` Storage**:
   - Automatic creation and management of the device storage directory.
   - Quick search, sorting (by date, name, file size), renaming, deletion, and sharing directly to other apps via standard share sheets.
6. **Fast Scrub & Index Drawer**:
   - Jump immediately to any page using thumbnail cards or navigation controls.

---

## 🗂️ `.zipr` File Container Specification

A `.zipr` file is a ZIP archive container structured as follows:

### Unencrypted `.zipr`:
```
document.zipr
├── manifest.json       # Document title, item order, dimensions, captions, sizes
├── media/
│   ├── item_0000.webp  # Compressed image page 1
│   ├── item_0001.mp4   # Compressed video page 2
│   └── item_0002.webp  # Compressed image page 3
└── thumbs/
    ├── thumb_0000.jpg  # Fast-scrub preview thumbnail
    └── thumb_0001.jpg
```

### Encrypted `.zipr` (AES-256):
```
secure_document.zipr
├── header.json         # Public metadata: title, itemCount, saltHex, ivHex, isEncrypted
└── payload.enc         # AES-256 encrypted binary payload of the inner ZIP archive
```

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.2.0 or higher)
- Android SDK (minSdk 21, targetSdk 34) or Xcode for iOS

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

### 4. Run Unit Tests
```bash
flutter test
```

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point & dark theme setup
├── models/
│   ├── zipr_item.dart                 # Individual media page model & byte formatting
│   └── zipr_manifest.dart             # Manifest schema & JSON serialization
├── services/
│   ├── compression_service.dart       # WebP & video transcoding pipelines
│   ├── encryption_service.dart        # AES-256 encryption & PBKDF2 key derivation
│   └── zipr_storage_service.dart      # /Documents/ZIPr directory & archive manager
├── widgets/
│   ├── compression_settings_modal.dart# Quality sliders & settings sheet
│   ├── password_dialog.dart           # AES-256 password prompt dialog
│   ├── zoomable_photo_widget.dart     # Double-tap & pinch-to-zoom photo viewer
│   └── zoomable_video_widget.dart     # Pinch-to-zoom video player with playback scrubber
└── screens/
    ├── home_library_screen.dart       # Library screen with search, sort, and storage stats
    ├── create_zipr_screen.dart        # Creation studio with reordering & compression
    └── zipr_feed_viewer_screen.dart   # PDF-like mixed media continuous feed viewer
```
