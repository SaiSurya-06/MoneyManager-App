# CI/CD Pipeline & Deployment Guide

## 1. Overview
The Money Manager project utilizes GitHub Actions for continuous integration and automated release artifact assembly. The pipeline configuration is located at `.github/workflows/flutter_ci.yml`.

---

## 2. Pipeline Stages

1. **Static Analysis & Linting**:
   - `flutter analyze`: Verifies no syntax errors, dead code, or compiler warnings.
2. **Automated Unit & Regression Tests**:
   - `flutter test --coverage`: Executes all 52 unit tests, verifying precision arithmetic, database migration v13, account archiving, credit cards, quick templates, daily rollover, budget exclusion, and monthly PDF generation.
3. **Android Build Verification**:
   - Generates release APK / App Bundle (`.aab`) with ProGuard obfuscation and resource shrinking enabled.

---

## 3. Required GitHub Secrets

To sign and deploy production Android releases, configure the following secrets in GitHub Repository Settings $\to$ Secrets and Variables $\to$ Actions:

| Secret Name | Description | Example / Format |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded Java keystore (`.jks`) | `base64 -w 0 upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | Password for the release keystore | `SecureKeystorePassword123!` |
| `KEY_ALIAS` | Key alias in keystore | `money-manager-key` |
| `KEY_PASSWORD` | Password for the key alias | `SecureKeyPassword123!` |
| `PLAY_STORE_JSON_KEY` | Google Play Developer API service account key | JSON key string |

---

## 4. Manual Local Release Build

```bash
# Clean project
flutter clean
flutter pub get

# Run test verification
flutter test

# Build production App Bundle
flutter build appbundle --release

# Build production APK
flutter build apk --release --split-per-abi
```
Release binaries will be generated at:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-*-release.apk`
