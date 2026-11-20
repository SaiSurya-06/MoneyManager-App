# Android CI and releases

Pushes to supported development branches and pull requests to the main branches run dependency resolution, static analysis, tests, and a debug APK build. The debug APK uses Android's debug signing and the `com.example.money_manager.debug` application ID, so it can be installed alongside the production app. Download it from the GitHub Actions run.

CI pins Flutter 3.27.4 with Dart 3.6.2 and enforces the checked-in lockfile. The production application ID is `com.example.money_manager`.

## Configure production signing

Create the GitHub Actions environment `android-release`, restrict deployments to the default branch, and enable required reviewers where supported. Configure these environment secrets in GitHub:

- `RELEASE_KEYSTORE_BASE64`
- `STORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

Set the environment variable `RELEASE_CERT_SHA256` to the approved signing certificate fingerprint. Obtain this fingerprint independently of the build output. Keep signing material in the environment secrets or an approved local signing setup.

Resolve release signing before publishing an update. Existing Android installations require a compatible signing identity or supported signing lineage. When that is unavailable, arrange a verified export and restore migration before instructing users to replace an existing install. The previously tracked signing material must be treated as exposed.

## Publish

In GitHub Actions, manually run **Flutter CI/CD** from the default branch with **Publish a signed APK from the default branch** enabled. The release job starts after CI succeeds and any environment approval is granted. It verifies the certificate, application ID, and version and publishes the APK and SHA-256 checksum to GitHub Releases.

Release version names come from `pubspec.yaml`. The workflow run number provides the Android version code. Check that this exceeds the version code used by the intended distribution channel when migrating to a new workflow or release channel.
