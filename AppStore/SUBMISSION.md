# Just Nurikabe: App Store submission runbook

State as of 2026-09-27: the submission kit is complete locally (metadata,
screenshots, IAP artwork, support site, privacy page). **Nothing exists in App
Store Connect yet.** The record has to be created on the web first (§1); the
rest is then staged by API and stops before any review submission.

## App record facts

- Name **Just Nurikabe** · bundle `de.kaikunze.nurikabe` · SKU `just-nurikabe-01`
  · primary locale en-US · team `8H42EZRCCP`
- ASC App ID: _fill in once created_
- IAP `de.kaikunze.nurikabe.full`, non-consumable, $4.99, family-shareable,
  display name **The Full Chart**, ASC id: _fill in_
- Always pass `--platform IOS` to AppShip (a record can carry several platform
  versions, and AppShip takes the first one it gets back).
- `whatsNew` stays empty on 1.0: it returns 409 on a first version.

## 1. What is left

Kai, before anything else:
- [ ] **Name check.** Search "Nurikabe" on J-PlatPat and USPTO (classes 9 and
      28/41) before committing the name. The listing never names a publisher.
- [ ] **Create the app record** on the web (record creation has no public API):
      name, bundle, SKU and locale as above.

Then by API (me), reading every change back:
- [ ] IAP: price, localization (description ≤55 characters, the
      `IAP_DESCRIPTION` in `iap/generate.py`), review screenshot and promo image.
- [ ] App info: subtitle, Games › Puzzle + Board, age rating 4+, privacy URL,
      copyright `2026 Kai Kunze`, `DOES_NOT_USE_THIRD_PARTY_CONTENT`, price Free,
      all territories.
- [ ] Version 1.0: description, keywords, promo text, support and marketing URL,
      review details (contact as on the siblings, `demoAccountRequired=false`,
      notes from `metadata/review-notes.txt`), release `MANUAL`.
- [ ] Screenshots: iPhone 6.5" and iPad 12.9", every asset `COMPLETE`.
- [ ] Build 1.0 (1): archive, export, validate, upload, `VALID`, attach.
- [ ] Site: repo `kkai/justnurikabe` with **only an orphan `gh-pages`** branch
      (`index.html`, `justnurikabe-privacy.html`, `shot-*.png`). The source repo
      stays local, because early commits named the publisher. Wait for 200 on
      `https://kaikunze.de/justnurikabe/` and the privacy page before those URLs go
      into ASC.

Kai, on the web, at the end:
- [ ] **Attach the IAP to the version** ("In-App Purchases and Subscriptions" on
      the 1.0 page). See §2.
- [ ] **App Privacy → "Data Not Collected".** No public API. It matches
      `PrivacyInfo.xcprivacy` (UserDefaults, CA92.1) and the privacy page.
- [ ] **Add for Review / Submit.**

## 2. Traps inherited from the siblings

**The first IAP must be an item in the review submission.** Just Kakuro's
visionOS 1.0 was rejected under 2.1(b) with its IAP fully configured
(`READY_TO_SUBMIT`) but attached to nothing. Via the API the relationship on
`reviewSubmissionItems` is `inAppPurchaseVersion`; `POST
/v1/inAppPurchaseSubmissions` does not work for a first submission. If the
version goes in without it, cancel (`PATCH {canceled: true}`); ASC then creates a
replacement submission that already holds the IAP.

**Guideline 4.3(a).** Just Shikaku was rejected as spam alongside its siblings.
Nurikabe's listing, site, paywall and lesson copy share no sentence with any
sibling; `python3 Tools/ListingCheck/sentence_diff.py` enforces that and the
character limits and exits 1 on any hit. The review notes open with what only
this app does: the rules chapter with rule-naming feedback, nine technique
lessons, a hint ladder that draws its argument, seals earned from unaided
deductions, every board proven unique and solvable by those nine techniques.

**Don't create empty `reviewSubmissions`** while exploring the API: they linger
and block the real one.

## 3. Prepared locally

| | |
|---|---|
| Description / promo / keywords | 1918 / 150 / 97 characters |
| Subtitle | `Paint the sea, find islands` (27 of 30) |
| Review notes | `metadata/review-notes.txt`, 1480 characters |
| Screenshots | 10 iPhone 6.5" (1242×2688) + 10 iPad 12.9" (2048×2732), light then dark, RGB |
| IAP artwork | `iap/nurikabe-full.png` 1024², `iap/review-screenshot-2048x2732.png`, RGB |
| Site | `index.html`, `justnurikabe-privacy.html`, `shot-*.png`; no external requests |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in the build settings |
| Privacy manifest | UserDefaults / CA92.1, key names pinned by `ReleaseBuildTests` |

## 4. Regenerating

```bash
python3 AppStore/capture_screenshots.py          # both devices, light + dark
python3 AppStore/iap/generate.py                 # IAP promo + review screenshot
python3 Tools/ListingCheck/sentence_diff.py      # 4.3 guard + limits

cd ../../studio/appstoreconnect/appship
.build/release/AppShip metadata --bundle-id de.kaikunze.nurikabe \
  --create-version 1.0 --locale en-US --platform IOS \
  --description-file … --promo-file … --keywords-file …
.build/release/AppShip screenshots --bundle-id de.kaikunze.nurikabe \
  --create-version 1.0 --locale en-US --platform IOS \
  --iphone-dir …/AppStore/screenshots/iphone-65 --ipad-dir …/AppStore/screenshots/ipad --replace
```

Verify through the API, not the exit code: AppShip has reported success on a
rejected upload. Screenshots carry `assetDeliveryState`; IAP images carry
`state`, where `PREPARE_FOR_SUBMISSION` is healthy.

The screenshot scenes come from the DEBUG-only launch argument
`-NurikabeScreenshotScene <hint|lesson|path|home|win>`, which seeds its own
state. A scene pushes its screen after Home appears: launching with the path
already filled left Home's dark nav-bar scheme on the pushed screen.

## 5. Build and upload

Key values come from `studio/appstoreconnect/credentials.txt` (line 2 issuer,
line 4 key id); never write them here.

```bash
xcodebuild archive -project Nurikabe.xcodeproj -scheme Nurikabe -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/JustNurikabe.xcarchive \
  -allowProvisioningUpdates -authenticationKeyPath <p8> \
  -authenticationKeyID <KEY_ID> -authenticationKeyIssuerID <ISSUER_ID>
xcodebuild -exportArchive -archivePath build/JustNurikabe.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates …
xcrun altool --validate-app -f build/export/Nurikabe.ipa -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
xcrun altool --upload-app   -f build/export/Nurikabe.ipa -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

Distribution signing happens at export through a cloud-managed certificate;
the API key on both steps is what allows it. `CURRENT_PROJECT_VERSION` is the
build number (1) and must rise with each upload for the same version.

Check the `.ipa` before uploading: no `.storekit`, no `*.debug.dylib` or
`__preview.dylib`, `PrivacyInfo.xcprivacy` present, and `strings` clean of
`NurikabeScreenshotScene` and `NurikabeScreenshotUnlock`.

## 6. Traps

- App Store artwork must have no alpha (ITMS-90717). Every generator saves RGB.
- `APP_IPHONE_67` uploads are accepted by the API and never shown in ASC. Use
  `APP_IPHONE_65` and `APP_IPAD_PRO_3GEN_129`; a set holds at most 10.
- The IAP description caps at 55 characters; the IAP review screenshot must be
  exactly 2048×2732.
- The review contact phone needs `+countrycode` format.
- Simulators: pin `OS=18.5`; same-named devices exist on other runtimes.
