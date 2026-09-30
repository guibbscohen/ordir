# TestFlight via Xcode Cloud

How to get Ordir builds onto testers' iPhones. The project side is ready:
- the app icon is a 1024×1024 PNG with no transparency;
- `PrivacyInfo.xcprivacy` declares no tracking and no data collected, plus the one required-reason API the app uses (`UserDefaults`, reason CA92.1);
- `ITSAppUsesNonExemptEncryption = NO` skips the export-compliance question on every build;
- the `Ordir` scheme is shared, which Xcode Cloud needs.

The rest needs your Apple account.

## Once

1. **Apple Developer Program.** Enrol at developer.apple.com ($99/year). Xcode Cloud includes 25 compute hours a month.
2. **Bundle ID.** Decide on the final one; `com.guibbscohen.ordir` is a placeholder. It can't change after the first upload.
3. **Signing.** In Xcode, select the Ordir target → Signing & Capabilities → choose your Team.
4. **App record.** In App Store Connect → Apps → **+** → New App:
   - Platform: iOS.
   - Name: Ordir. If it's taken, add a subtitle-style suffix.
   - Bundle ID: the one from step 2.
   - SKU: any unique text, e.g. `ordir`.
5. **Xcode Cloud workflow.** In Xcode → Integrate → Create Workflow, then allow access to the GitHub repo when asked:
   - Start condition: changes to `main`.
   - Action: Archive – iOS, with deployment preparation "TestFlight (Internal Testing Only)".
   - Post-action: TestFlight Internal Testing, sending builds to a tester group.
   - Leave out test actions: GitHub Actions already runs the unit tests, and Xcode Cloud hours are limited.

Xcode Cloud numbers each build itself, so `CURRENT_PROJECT_VERSION` never needs bumping.

## Testers

- **Internal:**
  - up to 100 people on your App Store Connect team;
  - no review;
  - builds arrive minutes after processing.
- **External:**
  - anyone, by email or public link;
  - the first build of each version goes through Beta App Review;
  - needs Test Information (what to test, a feedback email);
  - the app shows crops from CMON's rulebooks, so get CMON's permission first.
