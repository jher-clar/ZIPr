# ☁️ ZIPr — Cloud Storage Vault & Multi-Provider Hub

ZIPr now features a complete **Cloud Storage Vault** architecture supporting **Google Drive**, **MEGA.nz**, **OneDrive / OneCloud**, **MegaDrive / WebDAV**, and **Direct Cloud Link Ingestion**.

---

## 🚀 Key Cloud Storage Features

### 1. 🌐 Supported Cloud Providers & Account Sync
- **Google Drive (GDrive)**:
  - Account sync & Quota gauge (e.g. `34.0 GB used of 100 GB`).
  - Read, Stream, Download, and Upload `.zipr` containers.
- **MEGA.nz**:
  - Zero-knowledge end-to-end encrypted cloud container storage.
  - Full support for AES-256 encrypted `.zipr` archives.
- **OneDrive / OneCloud**:
  - Microsoft cloud container synchronization.
- **MegaDrive / WebDAV**:
  - Self-hosted & custom cloud storage endpoints.
- **Direct Cloud Link Import**:
  - Paste any public / shared URL (`Google Drive`, `MEGA.nz`, `OneDrive`, or direct HTTP link) to download and index in the local library.

---

### 2. ⚡ Core Cloud Workflows
- **👁️ Read & Stream Directly from Cloud**:
  - Stream any remote `.zipr` container on demand into a secure temporary cache without manual downloading.
  - Automatically triggers AES-256 password prompt if the cloud container is encrypted, then launches the continuous document feed viewer.
- **⬇️ Download to Device**:
  - One-tap download of any cloud container directly to the device's dedicated ZIPr storage directory (`/storage/emulated/0/Download/ZIPr` or app documents).
  - Automatically indexed and available offline in the local Library.
- **☁️ Upload to Cloud Vault**:
  - Upload local `.zipr` archives from the Library action menu (`[☁ Upload to Cloud]`) to any connected provider.
  - Multi-chunk upload progress modal showing live percentage, transfer speed, and status messages.
- **⚙️ Cloud Account Management**:
  - Seamlessly switch, connect, and update cloud account credentials and WebDAV servers.

---

## 🧪 Verification & Release APK

- **Automated Tests**: 15/15 tests passed in `flutter test` across all packaging, encryption, gesture zoom, HandBrake transcoding, and Cloud Vault sync engines.
- **Static Analysis**: `flutter analyze` completed with 0 errors.
- **Universal Release APK**:
  - Location: [ZIPr-release.apk](file:///c:/Users/Sanvee's%20By%20Tony/Downloads/ZIPr/ZIPr-release.apk) (63.0 MB)
