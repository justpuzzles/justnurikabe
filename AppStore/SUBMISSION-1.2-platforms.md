# Just Nurikabe 1.2 (4): Mac, Apple TV, Vision Pro — first release

Branch `multiplatform` (pushed to justpuzzles/justnurikabe, not merged).
Staged 2026-11-12. iOS is separate: 1.1 is live, iOS 1.2 is not uploaded.

| Platform | Version id | Build (delivery id) | Draft review submission | Gate |
|---|---|---|---|---|
| MAC_OS | 6f91a94a-c70e-4924-9c9d-f42d353e9d0c | 1.2 (4) ad7ddbb1-7676-4dec-a179-a773aed21889 | 00f9dcfe-70a8-4a01-b2e7-2c8ebc9800f6 | passed |
| TV_OS | 80c3a17e-8dcd-4693-9f3a-1725b98f11a9 | 1.2 (4) 39c96369-82df-492b-80cc-fb0b214a4e79 | c6afb55c-3245-476b-a7eb-3434b89a9b4c | passed |
| VISION_OS | a6c5a38a-4f8d-407b-b12c-b52dc133fe6e | 1.2 (4) 96584967-1ffd-4824-99d5-1411fabc4c0d | 86e30c0c-5b77-4b7c-b010-f204c9d51ab6 (empty) | **blocked**: `hasHighMotionLabel` |

## Done

- The 1.0 placeholders renamed to 1.2, copyright, release after approval.
- en-US listing from `AppStore/metadata/`, adjusted per platform: "click" on
  the Mac, remote wording and no VoiceOver claim on Apple TV (untested
  there), and each platform's line in place of "iPhone and iPad". Keywords,
  promotional text, URLs as on iOS. No What's New on a first version.
- Review notes: the iOS notes, the shared purchase (one bundle id), and that
  platform's controls.
- Screenshots, four per platform (home, hint, lesson, solved), `COMPLETE`:
  `AppStore/screenshots/{mac,tv,vision}/`, from `-NurikabeScreenshotScene`.
- Builds archived with cloud signing (`build/archive-1.2-4.sh`, ignored) from
  7bf5430, inspected (1.2 (4), privacy manifest, no `.storekit`, no debug
  flags), `--validate-app` clean, uploaded, `VALID`, attached.
- The IAP `de.kaikunze.nurikabe.full` is APPROVED from iOS, so it does not
  need to ride along.

## Left for Kai

1. **Vision Pro high-motion question** on the web (no fast motion: No); then
   add the version to submission 86e30c0c, or submit from the version page.
2. Submit each platform (web, or `PATCH reviewSubmissions/<id>`
   `{"attributes":{"submitted":true}}`).
3. Merge `multiplatform` into `main`.
