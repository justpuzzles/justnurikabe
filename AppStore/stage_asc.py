#!/usr/bin/env python3
"""Stage Just Nurikabe 1.0 in App Store Connect, step by step. Never submits.

    python3 AppStore/stage_asc.py <step> [<step> ...]

Steps (each reads its result back and prints it):

  info         subtitle, categories, age rating, content rights, copyright, MANUAL release
  urls         privacy URL, support + marketing URL (curl them to 200 first)
  version      description, keywords, promo text, review contact and notes
  price        app price Free (base USA) and availability in every territory
  iap          the non-consumable, localization, price, availability
  iap-images   IAP review screenshot + promo image
  screenshots  iPhone 6.5" + iPad 12.9" sets from AppStore/screenshots
  attach       attach the newest VALID build to the version
  status       read everything back

Credentials come from studio/appstoreconnect (asc.py); no ids or keys live here.
Nothing in this script creates a reviewSubmission: that step is Kai's.
"""
import hashlib, importlib.util, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ASC = os.path.join(ROOT, "..", "..", "studio", "appstoreconnect", "asc.py")
spec = importlib.util.spec_from_file_location("asc", ASC)
asc = importlib.util.module_from_spec(spec)
sys.argv, _argv = sys.argv[:1], sys.argv          # asc.py only parses argv under __main__
spec.loader.exec_module(asc)
sys.argv = _argv

APP = "6816718565"
BUNDLE = "de.kaikunze.nurikabe"
PRODUCT = "de.kaikunze.nurikabe.full"
SITE = "https://kaikunze.de/justnurikabe/"
PRIVACY = SITE + "justnurikabe-privacy.html"
META = os.path.join(HERE, "metadata")
IAP_DESCRIPTION = "Advanced lessons, 10×10 boards and hints that explain"


def call(method, path, params=None, body=None, ok=True):
    r = asc.call(method, path, params=params, body=body)
    if ok and isinstance(r, dict) and "HTTP_ERROR" in r:
        raise SystemExit(f"{method} {path} failed: {json.dumps(r, indent=1)[:2000]}")
    return r


def text(name):
    return open(os.path.join(META, name), encoding="utf-8").read().strip()


def ios_version():
    r = call("GET", f"apps/{APP}/appStoreVersions", {"filter[platform]": "IOS"})
    return r["data"][0]["id"]


def app_info():
    r = call("GET", f"apps/{APP}/appInfos")
    return next(i["id"] for i in r["data"] if i["attributes"].get("state") != "READY_FOR_DISTRIBUTION")


def one(path, params=None):
    return call("GET", path, params)["data"][0]["id"]


# ---------------------------------------------------------------- steps

def step_info():
    ai = app_info()
    loc = one(f"appInfos/{ai}/appInfoLocalizations")
    call("PATCH", f"appInfoLocalizations/{loc}", body={"data": {
        "type": "appInfoLocalizations", "id": loc,
        "attributes": {"subtitle": text("subtitle.txt")}}})
    call("PATCH", f"appInfos/{ai}", body={"data": {"type": "appInfos", "id": ai, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
        "primarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_PUZZLE"}},
        "primarySubcategoryTwo": {"data": {"type": "appCategories", "id": "GAMES_BOARD"}}}}})
    # Every answer none/false (the same declaration as Hashi's live record): 4+.
    none = ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
            "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
            "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
            "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic"]
    false = ["advertising", "ageAssurance", "gambling", "healthOrWellnessTopics", "lootBox",
             "messagingAndChat", "parentalControls", "unrestrictedWebAccess", "userGeneratedContent"]
    attrs = {k: "NONE" for k in none} | {k: False for k in false}
    call("PATCH", f"ageRatingDeclarations/{ai}", body={"data": {
        "type": "ageRatingDeclarations", "id": ai, "attributes": attrs}})
    call("PATCH", f"apps/{APP}", body={"data": {"type": "apps", "id": APP, "attributes": {
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    v = ios_version()
    call("PATCH", f"appStoreVersions/{v}", body={"data": {"type": "appStoreVersions", "id": v, "attributes": {
        "copyright": "2026 Kai Kunze", "releaseType": "MANUAL"}}})
    print("info staged")


def step_urls():
    for url in (SITE, PRIVACY):
        with urllib.request.urlopen(url) as r:
            assert r.status == 200, url
    ai = app_info()
    loc = one(f"appInfos/{ai}/appInfoLocalizations")
    call("PATCH", f"appInfoLocalizations/{loc}", body={"data": {
        "type": "appInfoLocalizations", "id": loc, "attributes": {"privacyPolicyUrl": PRIVACY}}})
    vloc = one(f"appStoreVersions/{ios_version()}/appStoreVersionLocalizations")
    call("PATCH", f"appStoreVersionLocalizations/{vloc}", body={"data": {
        "type": "appStoreVersionLocalizations", "id": vloc,
        "attributes": {"supportUrl": SITE, "marketingUrl": SITE}}})
    print("urls staged")


def step_version():
    v = ios_version()
    vloc = one(f"appStoreVersions/{v}/appStoreVersionLocalizations")
    attrs = {"description": text("description.txt"), "keywords": text("keywords.txt"),
             "promotionalText": text("promo.txt")}
    assert len(attrs["description"]) <= 4000 and len(attrs["keywords"]) <= 100 and len(attrs["promotionalText"]) <= 170
    call("PATCH", f"appStoreVersionLocalizations/{vloc}", body={"data": {
        "type": "appStoreVersionLocalizations", "id": vloc, "attributes": attrs}})
    review = {"contactFirstName": "Kai", "contactLastName": "Kunze", "contactPhone": "+4972544577",
              "contactEmail": "kai.kunze@gmail.com", "demoAccountRequired": False,
              "notes": text("review-notes.txt")}
    existing = call("GET", f"appStoreVersions/{v}/appStoreReviewDetail", ok=False)
    if existing.get("data"):
        rid = existing["data"]["id"]
        call("PATCH", f"appStoreReviewDetails/{rid}", body={"data": {
            "type": "appStoreReviewDetails", "id": rid, "attributes": review}})
    else:
        call("POST", "appStoreReviewDetails", body={"data": {
            "type": "appStoreReviewDetails", "attributes": review,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": v}}}}})
    print("version staged")


def all_territories():
    out, url = [], "territories?limit=200"
    while url:
        r = call("GET", url)
        out += [t["id"] for t in r["data"]]
        url = r.get("links", {}).get("next")
    return out


def step_price():
    r = call("GET", f"apps/{APP}/appPricePoints", {"filter[territory]": "USA", "limit": 200})
    free = next(p["id"] for p in r["data"] if float(p["attributes"]["customerPrice"]) == 0)
    call("POST", "appPriceSchedules", body={
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": APP}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free}}}}]})
    have = call("GET", f"apps/{APP}/appAvailabilityV2", ok=False)
    if "HTTP_ERROR" in have:
        terr = all_territories()
        call("POST", "https://api.appstoreconnect.apple.com/v2/appAvailabilities", body={
            "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
                     "relationships": {
                         "app": {"data": {"type": "apps", "id": APP}},
                         "territoryAvailabilities": {"data": [
                             {"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in terr]}}},
            "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}",
                          "attributes": {"available": True},
                          "relationships": {"territory": {"data": {"type": "territories", "id": t}}}}
                         for t in terr]})
        print(f"available in {len(terr)} territories")
    print("price staged: Free")


def iap_id():
    r = call("GET", f"apps/{APP}/inAppPurchasesV2", {"filter[productId]": PRODUCT})
    return r["data"][0]["id"] if r["data"] else None


def step_iap():
    iap = iap_id()
    if not iap:
        r = call("POST", "https://api.appstoreconnect.apple.com/v2/inAppPurchases", body={"data": {
            "type": "inAppPurchases",
            "attributes": {"name": "Nurikabe Full", "productId": PRODUCT,
                           "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": True,
                           "reviewNote": "Unlocks the last four technique lessons, 10×10 boards and the "
                                         "full in-game hint. Open any locked lesson on the Learn path, "
                                         "or Settings › Unlock the full game, to reach the purchase sheet."},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        iap = r["data"]["id"]
    locs = call("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap}/inAppPurchaseLocalizations")
    if not locs["data"]:
        assert len(IAP_DESCRIPTION) <= 55
        call("POST", "inAppPurchaseLocalizations", body={"data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {"locale": "en-US", "name": "The Full Chart", "description": IAP_DESCRIPTION},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})
    points = call("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap}/pricePoints",
                  {"filter[territory]": "USA", "limit": 8000})
    p499 = next(p["id"] for p in points["data"] if p["attributes"]["customerPrice"] == "4.99")
    call("POST", "inAppPurchasePriceSchedules", body={
        "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p}", "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": {
                          "data": {"type": "inAppPurchasePricePoints", "id": p499}}}}]})
    have = call("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap}/inAppPurchaseAvailability", ok=False)
    if "HTTP_ERROR" in have or not have.get("data"):
        terr = all_territories()
        call("POST", "inAppPurchaseAvailabilities", body={"data": {
            "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
    print("iap staged", iap)


def upload(reserve_type, rel_name, rel_type, rel_id, path):
    """Reserve, PUT every upload operation, commit with the MD5 checksum."""
    data = open(path, "rb").read()
    r = call("POST", reserve_type, body={"data": {
        "type": reserve_type, "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {rel_name: {"data": {"type": rel_type, "id": rel_id}}}}})
    rid = r["data"]["id"]
    for op in r["data"]["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req).read()
    call("PATCH", f"{reserve_type}/{rid}", body={"data": {
        "type": reserve_type, "id": rid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return rid


def step_iap_images():
    iap = iap_id()
    upload("inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", "inAppPurchases", iap,
           os.path.join(HERE, "iap", "review-screenshot-2048x2732.png"))
    upload("inAppPurchaseImages", "inAppPurchase", "inAppPurchases", iap,
           os.path.join(HERE, "iap", "nurikabe-full.png"))
    print("iap images uploaded")


def step_screenshots():
    vloc = one(f"appStoreVersions/{ios_version()}/appStoreVersionLocalizations")
    for display, folder in (("APP_IPHONE_65", "iphone-65"), ("APP_IPAD_PRO_3GEN_129", "ipad")):
        sets = call("GET", f"appStoreVersionLocalizations/{vloc}/appScreenshotSets")["data"]
        for s in sets:
            if s["attributes"]["screenshotDisplayType"] == display:
                call("DELETE", f"appScreenshotSets/{s['id']}")
        sid = call("POST", "appScreenshotSets", body={"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
            "relationships": {"appStoreVersionLocalization": {
                "data": {"type": "appStoreVersionLocalizations", "id": vloc}}}}})["data"]["id"]
        files = sorted(f for f in os.listdir(os.path.join(HERE, "screenshots", folder)) if f.endswith(".png"))
        assert len(files) <= 10, files
        for f in files:
            upload("appScreenshots", "appScreenshotSet", "appScreenshotSets", sid,
                   os.path.join(HERE, "screenshots", folder, f))
        print(display, len(files), "uploaded")


def step_attach():
    v = ios_version()
    r = call("GET", "builds", {"filter[app]": APP, "filter[processingState]": "VALID",
                               "sort": "-uploadedDate", "limit": 1})
    build = r["data"][0]
    call("PATCH", f"appStoreVersions/{v}/relationships/build",
         body={"data": {"type": "builds", "id": build["id"]}})
    print("attached build", build["attributes"]["version"])


def step_status():
    ai = app_info()
    v = ios_version()
    loc = call("GET", f"appInfos/{ai}/appInfoLocalizations")["data"][0]["attributes"]
    print("appInfo:", {k: loc[k] for k in ("name", "subtitle", "privacyPolicyUrl")})
    inf = call("GET", f"appInfos/{ai}", {"include": "primaryCategory,primarySubcategoryOne,primarySubcategoryTwo"})
    print("categories:", [x["id"] for x in inf.get("included", [])])
    va = call("GET", f"appStoreVersions/{v}", {"include": "build"})
    print("version:", {k: va["data"]["attributes"][k] for k in ("versionString", "appStoreState", "copyright", "releaseType")},
          "build:", [b["attributes"]["version"] for b in va.get("included", [])])
    vl = call("GET", f"appStoreVersions/{v}/appStoreVersionLocalizations")["data"][0]["attributes"]
    for k in ("description", "keywords", "promotionalText"):
        want = text({"description": "description.txt", "keywords": "keywords.txt", "promotionalText": "promo.txt"}[k])
        print(f"{k}: {len(vl[k] or '')} chars, matches file: {vl[k] == want}")
    print("urls:", vl["supportUrl"], vl["marketingUrl"])
    rd = call("GET", f"appStoreVersions/{v}/appStoreReviewDetail", ok=False)
    print("review detail:", bool(rd.get("data")) and {k: rd["data"]["attributes"][k] for k in ("contactEmail", "contactPhone", "demoAccountRequired")})
    app = call("GET", f"apps/{APP}", {"fields[apps]": "bundleId,contentRightsDeclaration"})["data"]["attributes"]
    print("app:", app)
    vloc = one(f"appStoreVersions/{v}/appStoreVersionLocalizations")
    for s in call("GET", f"appStoreVersionLocalizations/{vloc}/appScreenshotSets")["data"]:
        shots = call("GET", f"appScreenshotSets/{s['id']}/appScreenshots", {"limit": 20})["data"]
        states = sorted({x["attributes"]["assetDeliveryState"]["state"] for x in shots})
        print("screens:", s["attributes"]["screenshotDisplayType"], len(shots), states)
    iap = iap_id()
    if iap:
        a = call("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap}")["data"]["attributes"]
        print("iap:", iap, a["state"], a["productId"], "familySharable", a["familySharable"])
    subs = call("GET", "reviewSubmissions", {"filter[app]": APP}, ok=False)
    print("review submissions:", [(s["id"], s["attributes"].get("state")) for s in subs.get("data", [])])


STEPS = {"info": step_info, "urls": step_urls, "version": step_version, "price": step_price,
         "iap": step_iap, "iap-images": step_iap_images, "screenshots": step_screenshots,
         "attach": step_attach, "status": step_status}

if __name__ == "__main__":
    for name in sys.argv[1:] or ["status"]:
        STEPS[name]()
