# Known Issues & Future Enhancements

## 1. Known Non-Critical Issues

1. **Local Windows Development Environment Execution**:
   - The developer's local Windows workstation enforces an Application Control policy (Device Guard / WDAC) that prevents local execution of unsigned developer binaries (`dart.exe`). All test verification and builds are automated on GitHub Actions (`ubuntu-latest`).
2. **First-Time Background Alarm Scheduling on Android 14+**:
   - Android 14+ requires explicit `SCHEDULE_EXACT_ALARM` permissions granted by the user in system settings. If not granted, the app falls back to inexact alarms, which may jitter report generation by up to 15 minutes.
3. **Large Database PDF Page Layout**:
   - In cases where a single month contains over 5,000 transactions, generating the full transaction register within Report 1 can take several seconds. A pagination limit of top 1,000 items is recommended for high-volume accounts in future updates.

---

## 2. Planned Future Enhancements

- **Biometric Prompt on PDF Open**: Optional biometric check before opening or exporting monthly financial reports.
- **Direct Google Drive Backup for Monthly PDFs**: Automatic cloud mirroring of generated monthly report PDFs to Google Drive.
- **Customizable Billing Cycle Dates**: Multi-card statement calendar widget aggregating payment due dates across all credit cards on the home dashboard.
