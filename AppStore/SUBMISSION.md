# Just Nurikabe: App Store submission runbook

## 1.1 (3), staged 2026-11-08

**1.0 has been live since 2026-09-27 (READY_FOR_SALE, IAP APPROVED, never rejected).**
iOS 1.1 version `1be7dcd7-03fd-41b6-8edf-866074d38ce0`, release AFTER_APPROVAL.
Description, keywords, URLs, review notes and both screenshot sets (iPhone 6.5"
10, iPad 12.9" 10) carried over from 1.0; promotional text did not and was
pushed again. What's New is from `metadata/whatsnew-1.1.txt`. Build 3 (iOS 18.0
minimum) was uploaded from `main` at 1156cb3. To stage again from scratch:

```bash
python3 AppStore/stage_asc.py new-version whatsnew attach gate status
```

`gate` creates a DRAFT reviewSubmission holding the version (Apple's readiness
check); it never submits. To submit: Submit for Review on the web, or
`PATCH reviewSubmissions/<id>` with `attributes.submitted = true`. The IAP is
already approved and isn't part of this submission.

The site (`../nurikabe-site`, gh-pages of kkai/justnurikabe) has carried the App
Store badge since 2026-11-08, in the header and under the price.

---

1.0 history. State as of 2026-09-27: **staged in App Store Connect, not submitted.** The iOS
1.0 version is `PREPARE_FOR_SUBMISSION` with build 1 attached, all metadata and
screenshots in place, and the IAP `READY_TO_SUBMIT`. No reviewSubmission exists.
**Three things are left, all Kai's, all on the web (§1).**

## App record facts

- ASC App ID **6816718565** · SKU `just-nurikabe-01` · bundle `de.kaikunze.nurikabe`
  · primary locale en-US · team `8H42EZRCCP`
- The record was created with bundle `de.kaikunze.mathmaze`. It was repointed
  to `de.kaikunze.nurikabe` (explicit App ID `U72F74JQJ9`, registered for this)
  on 2026-09-27 **before the first build**. Now that build 1 has landed, the
  bundle id is locked.
- The record carries **four platform versions** (iOS, macOS, tvOS, visionOS),
  all 1.0. Only iOS ships. Always pass `--platform IOS` to AppShip;
  `AppStore/stage_asc.py` filters for IOS itself.
- iOS 1.0 version `ee66b82e-2c49-420f-8230-3b17d65ae070`, en-US localization
  `28668d93-c049-456d-9889-73731b95bc88`, appInfo
  `ddbd66de-76ea-441b-aaa0-1efe074497d0`.
- IAP `de.kaikunze.nurikabe.full`, ASC id **6816720258**, non-consumable, $4.99
  (base USA), family-shareable, display name **The Full Chart**, reference name
  "Nurikabe Full".
- `whatsNew` stays empty on 1.0: it returns 409 on a first version.

## 1. What is left

- [ ] **Name check** (if not done yet): "Nurikabe" on J-PlatPat and USPTO.
- [ ] **Add the IAP to the version**: on the iOS 1.0 page, section "In-App
      Purchases and Subscriptions", add *The Full Chart*. See §2.
- [ ] **App Privacy → "Data Not Collected"**, then Publish. No public API. It
      matches `PrivacyInfo.xcprivacy` (UserDefaults, CA92.1) and the policy page.
- [ ] **Add for Review / Submit** (iOS only; leave macOS, tvOS, visionOS alone).

Done by API on 2026-09-27 with `AppStore/stage_asc.py`, all read back:
- [x] Site: `kkai/justnurikabe`, **only** a `gh-pages` branch (no app source; its
      early commits named the publisher). Local clone `../nurikabe-site`.
      `https://kaikunze.de/justnurikabe/` and the privacy page return 200.
- [x] App info: subtitle, Games › Puzzle + Board, age rating (all none/false,
      same declaration as Hashi), privacy URL, `DOES_NOT_USE_THIRD_PARTY_CONTENT`.
- [x] Price Free (base USA), available in all 175 territories and new ones.
- [x] Version: description, keywords, promo text, support and marketing URL,
      copyright `2026 Kai Kunze`, release `MANUAL`, review contact and notes,
      `demoAccountRequired=false`.
- [x] Screenshots: 10 iPhone 6.5" + 10 iPad 12.9", every asset `COMPLETE`.
- [x] IAP: localization, $4.99 schedule, availability, review screenshot
      `COMPLETE`, promo image `PREPARE_FOR_SUBMISSION` (healthy).
- [x] Build 1.0 (1): archived and exported with API-key cloud signing, `.ipa`
      checked (no `.storekit`, no debug dylibs, privacy manifest present, no
      screenshot flag strings), `--validate-app` clean, uploaded (delivery
      `ce4ad533-b246-4513-b19b-989bff628a73`), `VALID`, attached.

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
| Description / promo / keywords | 1935 / 150 / 97 characters (as ASC counts) |
| Subtitle | `Paint the sea, find islands` (27 of 30) |
| Review notes | `metadata/review-notes.txt`, 1480 characters |
| Screenshots | 10 iPhone 6.5" (1242×2688) + 10 iPad 12.9" (2048×2732), light then dark, RGB |
| IAP artwork | `iap/nurikabe-full.png` 1024², `iap/review-screenshot-2048x2732.png`, RGB |
| Site | `index.html`, `justnurikabe-privacy.html`, `shot-*.png`; no external requests |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` in the build settings |
| Privacy manifest | UserDefaults / CA92.1, key names pinned by `ReleaseBuildTests` |

## 3a. Guideline audit (2026-09-27)

| Guideline | Status |
|---|---|
| 2.1 completeness | Release build runs on device; no placeholders; locked items open the paywall. Risk: the first IAP must ride in the submission (§2) |
| 2.3.1 accurate metadata | Each description claim checked against the code. Fixed: "five difficulties" now says 10×10 starts at Sharp |
| 2.3.2 paid features in screenshots | Screens show paid content (Only Way Out hint, full path); the description spells out what the purchase adds |
| 2.3.7 metadata terms | No publisher, competitor or platform names; no "best"/"#1" |
| 2.4.1 iPad | Universal, all iPad orientations, lesson and game layouts sized for regular width |
| 2.5.1 public APIs | SwiftUI, StoreKit 2, UIKit haptics only; no network code of its own |
| 3.1.1 IAP | StoreKit non-consumable; price from `displayPrice`; Restore in paywall and Settings; no outside payment wording |
| 4.3(a) spam | Highest risk (Shikaku's rejection). Distinct puzzle, look and copy; `sentence_diff.py` exits 0; review notes lead with the differences |
| 5.1.1(i) privacy policy | ASC URL plus in-app link (Settings › About, added in this audit, pinned by `ReleaseBuildTests`) |
| 5.1.1 / 5.1.2 data | Data Not Collected, no tracking, manifest CA92.1; matches the policy page |
| 5.2.1 IP | Open: trademark check on "Nurikabe" (§1) |
| Support URL (1.5) | Site has a contact address. **It must be live before submitting**: the support URL, privacy URL and both in-app links all point to `kaikunze.de/justnurikabe/` |
| EU (DSA) | Trader status is set per account; confirm it is still valid in ASC › Business |

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
