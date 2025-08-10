# Changelog

All notable changes to the DevOps scripts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2024-08-09

### Added

- **rotate-api-keys.sh** script for Google Cloud API key rotation
  - Support for 6 key types (prod-firebase, prod-maps, local-firebase, local-maps, server-maps, server-firebase)
  - Timestamped API key naming for tracking
  - Domain and API restrictions for security
  - Automatic project switching and restoration
  - Configuration via `.env` file for domains, bundle IDs, and API services

### Changed

- Moved API key configuration to `.env` file:
  - `PROD_DOMAIN` for production domain restrictions
  - `ANDROID_APP_PACKAGE_NAME` and `IOS_APP_BUNDLE_ID` for mobile apps
  - `LOCALHOST_DOMAINS` for development environments
  - Configurable API lists (`FIREBASE_APIS`, `MAPS_APIS`, `SERVER_FIREBASE_APIS`)

## [1.3.0] - 2024-08-09

### Added

- Support for GITHUB_OWNER and GITHUB_REPO in `.env` file for persistent repository configuration
- Repository detection priority system (parameter > .env > git auto-detection)
- Comprehensive submodule usage documentation (SUBMODULE_USAGE.md)
- Quick reference guide for common submodule commands (QUICK_REFERENCE.md)

### Changed

- Repository configuration can now be set in `.env` file instead of passing parameters
- Improved configuration messages showing source of repository setting

## [1.2.0] - 2024-08-09

### Added

- `--repo` parameter for `manage-github-secrets.sh` to specify custom repository
- Support for running scripts from git submodules with manual repository specification

### Changed

- Script can now work without git when `--repo` parameter is provided
- Improved error messages to guide users when running from submodules

## [1.1.0] - 2024-08-09

### Added

- Proper libsodium encryption for GitHub secrets using `libsodium-wrappers`
- Node.js helper script (`github-secret-encrypt.js`) for encrypting secrets
- Support for large secrets including service account JSON files
- Comprehensive documentation with README files for each directory
- Organized directory structure (common/, github/, google/)

### Changed

- Reorganized scripts into subdirectories by service type
- Updated all script paths to reference centralized `.env` file in `common/` directory
- Improved error handling for secret encryption failures
- Enhanced debug output for troubleshooting

### Fixed

- Fixed GitHub secret creation failing for large JSON files (e.g., service account keys)
- Fixed improper base64 encoding being used instead of proper encryption
- Fixed shell escaping issues with JSON containing special characters and newlines

### Security

- Implemented proper encryption using libsodium's `crypto_box_seal` function
- Secrets are now properly encrypted before being sent to GitHub API

## [1.0.0] - 2024-08-09

### Initial Release

- GitHub secrets management script with interactive and non-interactive modes
- Google Cloud service account creation for Fastlane and GitHub Actions
- Automatic GitHub secret creation for Fastlane service accounts
- Environment configuration via `.env` file
- Support for multiple GCP project management
- Automatic project switching and restoration

### Features

- **GitHub Secrets Manager**
  - Interactive menu for managing secrets
  - Add, update, and check secret existence
  - Automatic repository detection from git remote

- **Service Account Creator**
  - Fastlane account with Firebase App Distribution admin role
  - GitHub Actions account with comprehensive Firebase and GCP roles
  - Timestamped naming convention for tracking
  - JSON key file generation

### Roles Configured

- **Fastlane Service Account**
  - `roles/firebaseappdistro.admin` - Firebase App Distribution deployment

- **GitHub Actions Service Account**
  - `roles/artifactregistry.admin` - Artifact repository management
  - `roles/firebase.admin` - Firebase administration
  - `roles/firebasehosting.admin` - Firebase Hosting deployment
  - `roles/firebaseappcheck.admin` - Firebase App Check management
  - `roles/firebaseauth.admin` - Firebase Authentication management
  - `roles/cloudfunctions.admin` - Cloud Functions deployment
  - `roles/run.admin` - Cloud Run services management
  - `roles/storage.admin` - Cloud Storage management
  - `roles/iam.serviceAccountUser` - Service account impersonation
