# Phase A: Flavors & App Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give both Flutter apps (`drivio_driver`, `drivio_user`) `prod` + `staging` flavors with real `com.drivedrivio.*` identifiers, per-flavor display names and env files — the foundation for per-flavor Firebase apps (Phase B) and Agora calling (Phase C).

**Architecture:** `flutter_flavorizr` generates the native flavor scaffolding (Android `productFlavors`, iOS xcconfigs/schemes, Dart flavor targets); we then hand-fix what it can't do safely: Kotlin namespace/package move, re-applying custom manifest/plist entries it may clobber, and per-flavor dotenv loading in the existing `main.dart`.

**Tech Stack:** flutter_flavorizr ^2.2.x, Kotlin-DSL Gradle, Xcode xcconfig/schemes, flutter_dotenv.

## Global Constraints

- **No tests** — this project skips test files by user decision; verification = `flutter analyze` + real builds per flavor.
- **No commits unless the user asks** — end-of-task verification replaces commit steps; the user commits/pushes.
- Android appIds: `com.drivedrivio.drivio_driver` / `com.drivedrivio.drivio_rider`; staging appends `.beta`.
- iOS bundle IDs (no underscores allowed): `com.drivedrivio.drivio-driver` / `com.drivedrivio.drivio-rider`; staging appends `.beta`.
- Display names: "Drivio Driver" / "Drivio"; staging appends " Beta".
- Preserve untouched: driver FGS (`flutter_foreground_task`) manifest entries, iOS location shim/background modes, camera + location permission strings, existing `main.dart` init (dotenv, DI, Supabase).
- Repos: `/Users/ebube.okocha/StudioProjects/drivio_driver`, `/Users/ebube.okocha/StudioProjects/drivio_user`.

---

### Task 1: Driver — flavorizr config + generation

**Files:**
- Modify: `drivio_driver/pubspec.yaml` (dev_dependency + `flavorizr:` block)
- Generated (expect): `lib/flavors.dart`, `lib/main_prod.dart`, `lib/main_stage.dart`, `android/app/build.gradle.kts` (productFlavors), `ios/Flutter/prod.xcconfig`, `ios/Flutter/staging.xcconfig`, Xcode schemes `prod`/`staging`

**Interfaces:**
- Produces: `enum Flavor { prod, staging }` and `F.appFlavor` in `lib/flavors.dart`; entrypoints `lib/main_prod.dart` / `lib/main_stage.dart` that set the flavor then delegate to `main.dart`'s `main()`.

- [ ] **Step 1: Snapshot the files flavorizr may rewrite** (for diff-review later)

```bash
cd /Users/ebube.okocha/StudioProjects/drivio_driver
mkdir -p /tmp/flavorizr-backup/driver
cp android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist /tmp/flavorizr-backup/driver/
cp ios/Runner.xcodeproj/project.pbxproj /tmp/flavorizr-backup/driver/project.pbxproj
```

- [ ] **Step 2: Add flavorizr to pubspec**

In `dev_dependencies`: `flutter_flavorizr: ^2.2.3`. At the pubspec top level add:

```yaml
flavorizr:
  instructions:
    - android:androidManifest
    - android:buildGradle
    - flutter:flavors
    - flutter:targets
    - ios:xcconfig
    - ios:buildTargets
    - ios:schema
    - ios:plist
  flavors:
    prod:
      app:
        name: "Drivio Driver"
      android:
        applicationId: "com.drivedrivio.drivio_driver"
      ios:
        bundleId: "com.drivedrivio.drivio-driver"
    staging:
      app:
        name: "Drivio Driver Beta"
      android:
        applicationId: "com.drivedrivio.drivio_driver.beta"
      ios:
        bundleId: "com.drivedrivio.drivio-driver.beta"
```

The trimmed `instructions` list is deliberate: no `flutter:app`/`flutter:pages`/`flutter:main` (would overwrite the real `main.dart`), no icon/asset/firebase processors (Phase B handles Firebase).

- [ ] **Step 3: Run flavorizr**

```bash
flutter pub get && dart run flutter_flavorizr
```
Expected: exits 0; generates `lib/flavors.dart`, `lib/main_prod.dart`, `lib/main_stage.dart`; adds `flavorDimensions`/`productFlavors` to `android/app/build.gradle.kts`; creates `ios/Flutter/{prod,staging}.xcconfig` + schemes. If the iOS processor complains about the `xcodeproj` Ruby gem: `sudo gem install xcodeproj` and re-run.

- [ ] **Step 4: Fallback if the Kotlin-DSL Gradle processor fails**

If `android:buildGradle` errors on `.kts`, hand-add inside `android { }` of `android/app/build.gradle.kts`:

```kotlin
    flavorDimensions += "flavor"
    productFlavors {
        create("prod") {
            dimension = "flavor"
            applicationId = "com.drivedrivio.drivio_driver"
            resValue(type = "string", name = "app_name", value = "Drivio Driver")
        }
        create("staging") {
            dimension = "flavor"
            applicationId = "com.drivedrivio.drivio_driver.beta"
            resValue(type = "string", name = "app_name", value = "Drivio Driver Beta")
        }
    }
```

and set `android:label="@string/app_name"` in `android/app/src/main/AndroidManifest.xml` (keep every other manifest attribute/entry as-is).

- [ ] **Step 5: Diff-review the clobber-prone files**

```bash
diff /tmp/flavorizr-backup/driver/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
diff /tmp/flavorizr-backup/driver/Info.plist ios/Runner/Info.plist
diff /tmp/flavorizr-backup/driver/build.gradle.kts android/app/build.gradle.kts
```
Re-apply anything lost: FGS `<service>` declarations + `FOREGROUND_SERVICE*`/`CAMERA`/location permissions in the manifest; `NSCameraUsageDescription`, location usage strings, `UIBackgroundModes` in Info.plist. The only *intended* manifest change is the label; the only intended Info.plist changes are `CFBundleDisplayName`/`CFBundleName` becoming `$(...)` xcconfig variables.

- [ ] **Step 6: Verify analyze passes**

```bash
flutter analyze lib/flavors.dart lib/main_prod.dart lib/main_stage.dart
```
Expected: No issues found.

---

### Task 2: Driver — namespace + Kotlin package move to com.drivedrivio

**Files:**
- Modify: `android/app/build.gradle.kts` (`namespace`)
- Move: `android/app/src/main/kotlin/com/example/drivio_driver/*.kt` → `android/app/src/main/kotlin/com/drivedrivio/drivio_driver/`

**Interfaces:**
- Produces: `namespace = "com.drivedrivio.drivio_driver"`; all Kotlin files under the new package with matching `package` lines. (Namespace is flavor-independent; only `applicationId` varies per flavor.)

- [ ] **Step 1: Enumerate Kotlin sources** (driver has FGS/location native code — move all of them)

```bash
find android/app/src/main/kotlin -name "*.kt"
```

- [ ] **Step 2: Move + rewrite package lines**

```bash
mkdir -p android/app/src/main/kotlin/com/drivedrivio/drivio_driver
git mv android/app/src/main/kotlin/com/example/drivio_driver/*.kt android/app/src/main/kotlin/com/drivedrivio/drivio_driver/ 2>/dev/null || mv android/app/src/main/kotlin/com/example/drivio_driver/*.kt android/app/src/main/kotlin/com/drivedrivio/drivio_driver/
```
In each moved file change `package com.example.drivio_driver` → `package com.drivedrivio.drivio_driver` (keep sub-suffixes if any). Delete the now-empty `com/example` tree.

- [ ] **Step 3: Update namespace**

In `android/app/build.gradle.kts`: `namespace = "com.drivedrivio.drivio_driver"`.

- [ ] **Step 4: Check for hardcoded old package refs**

```bash
grep -rn "com.example.drivio_driver" android ios lib | grep -v build/
```
Expected: no hits (AndroidManifest uses relative `.MainActivity`, which follows the namespace). Fix any stragglers.

---

### Task 3: Driver — per-flavor env loading

**Files:**
- Create: `.env.prod`, `.env.staging` (copies of `.env`)
- Modify: `lib/main.dart` (flavor-aware dotenv), `pubspec.yaml` (assets)

**Interfaces:**
- Consumes: `F.appFlavor` from `lib/flavors.dart` (Task 1).
- Produces: `main()` loads `.env.prod` or `.env.staging` by flavor, falling back to `.env` when run without a flavor target (dev convenience).

- [ ] **Step 1: Create the env files**

```bash
cp .env .env.prod && cp .env .env.staging
```
(Same Supabase values for now — flavors diverge in Phase B via Firebase, and later if a staging Supabase appears.)

- [ ] **Step 2: Register assets** — in `pubspec.yaml` `assets:` add `- .env.prod` and `- .env.staging` (keep `- .env`).

- [ ] **Step 3: Flavor-aware load in `lib/main.dart`**

Replace `await dotenv.load(fileName: '.env');` with:

```dart
  // Flavor targets (main_prod/main_staging) set F.appFlavor before calling
  // this main(); a bare `flutter run` leaves it null → plain .env.
  final String envFile = switch (F.appFlavor) {
    Flavor.prod => '.env.prod',
    Flavor.staging => '.env.staging',
    null => '.env',
  };
  await dotenv.load(fileName: envFile);
```
with `import 'package:drivio_driver/flavors.dart';` added. If the generated `flavors.dart` declares `F.appFlavor` non-nullable, make it `static Flavor? appFlavor;` so the null branch is real.

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/main.dart lib/flavors.dart
```
Expected: No issues found.

---

### Task 4: Driver — build gates (both flavors, both platforms)

**Files:** none (verification only)

- [ ] **Step 1: Android builds**

```bash
flutter build apk --debug --flavor staging -t lib/main_stage.dart
flutter build apk --debug --flavor prod -t lib/main_prod.dart
```
Expected: both succeed; `aapt`-visible appIds end in `.drivio_driver.beta` / `.drivio_driver`.

- [ ] **Step 2: iOS build (no codesign)**

```bash
flutter build ios --debug --no-codesign --flavor staging -t lib/main_stage.dart
```
Expected: succeeds using the `staging` scheme; bundle id `com.drivedrivio.drivio-driver.beta`.

- [ ] **Step 3: Full analyze**

```bash
flutter analyze
```
Expected: no errors/warnings introduced (pre-existing infos allowed).

---

### Task 5: Rider — flavorizr config + generation

Mirror of Task 1 in `/Users/ebube.okocha/StudioProjects/drivio_user`, with rider values. Same instructions list, same backup/diff-review flow (backup dir `/tmp/flavorizr-backup/rider`; rider's clobber-watch list: `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` in Info.plist; `CAMERA` + location permissions in the manifest).

**Flavorizr block (rider `pubspec.yaml`):**

```yaml
flavorizr:
  instructions:
    - android:androidManifest
    - android:buildGradle
    - flutter:flavors
    - flutter:targets
    - ios:xcconfig
    - ios:buildTargets
    - ios:schema
    - ios:plist
  flavors:
    prod:
      app:
        name: "Drivio"
      android:
        applicationId: "com.drivedrivio.drivio_rider"
      ios:
        bundleId: "com.drivedrivio.drivio-rider"
    staging:
      app:
        name: "Drivio Beta"
      android:
        applicationId: "com.drivedrivio.drivio_rider.beta"
      ios:
        bundleId: "com.drivedrivio.drivio-rider.beta"
```

Kotlin-DSL fallback (if needed), inside rider `android/app/build.gradle.kts`:

```kotlin
    flavorDimensions += "flavor"
    productFlavors {
        create("prod") {
            dimension = "flavor"
            applicationId = "com.drivedrivio.drivio_rider"
            resValue(type = "string", name = "app_name", value = "Drivio")
        }
        create("staging") {
            dimension = "flavor"
            applicationId = "com.drivedrivio.drivio_rider.beta"
            resValue(type = "string", name = "app_name", value = "Drivio Beta")
        }
    }
```

- [ ] Steps 1–6 as in Task 1 (backup → pubspec → run → kts fallback → diff-review → analyze).

---

### Task 6: Rider — namespace + Kotlin package move

Mirror of Task 2: `com.example.drivio_user` → `com.drivedrivio.drivio_rider` (note: the *package path* also changes `drivio_user` → `drivio_rider` to match the new namespace).

- [ ] Move `android/app/src/main/kotlin/com/example/drivio_user/*.kt` → `android/app/src/main/kotlin/com/drivedrivio/drivio_rider/`, rewrite `package` lines to `com.drivedrivio.drivio_rider`.
- [ ] `namespace = "com.drivedrivio.drivio_rider"` in `android/app/build.gradle.kts`.
- [ ] `grep -rn "com.example.drivio_user" android ios lib | grep -v build/` → expected empty.

---

### Task 7: Rider — per-flavor env loading

Mirror of Task 3 (rider `main.dart` currently: `await dotenv.load(fileName: '.env');` at line ~15). Same switch on `F.appFlavor`, import `package:drivio_user/flavors.dart`, create `.env.prod`/`.env.staging`, register assets.

- [ ] Steps 1–4 as in Task 3.

---

### Task 8: Rider — build gates

Mirror of Task 4:

- [ ] `flutter build apk --debug --flavor staging -t lib/main_stage.dart` and `--flavor prod -t lib/main_prod.dart` → both succeed.
- [ ] `flutter build ios --debug --no-codesign --flavor staging -t lib/main_stage.dart` → succeeds.
- [ ] `flutter analyze` → clean.

---

### Task 9: Run-config documentation

**Files:**
- Modify: `drivio_driver/README.md`, `drivio_user/README.md` (or create a `docs/flavors.md` in each if no README section fits)

- [ ] Add a short "Running flavors" section to each repo:

```markdown
## Running flavors

| Flavor | Run |
|---|---|
| Staging (Beta) | `flutter run --flavor staging -t lib/main_stage.dart` |
| Production | `flutter run --flavor prod -t lib/main_prod.dart` |

Plain `flutter run` (no flavor) still works for quick dev and loads `.env`.
Env files: `.env.staging` / `.env.prod` (checked-in keys only — no secrets).
```

- [ ] Final gate: report both apps' flavor matrix (appId/bundleId/display name) back to the user and stop — **Phase B (Firebase) gets its own plan** once these builds are confirmed.

## Self-Review

- **Spec coverage:** flavor table ✓ (Tasks 1/5), underscore→hyphen iOS rule ✓, `.beta` suffixes ✓, per-flavor dotenv ✓ (Tasks 3/7), flavorizr clobber-risk mitigation ✓ (backup+diff steps), build verification gate ✓ (Tasks 4/8). Firebase/push intentionally out (Phase B plan).
- **Placeholders:** none — every step has exact commands/code.
- **Type consistency:** `Flavor` enum + nullable `F.appFlavor` used identically in Tasks 1/3/5/7.
