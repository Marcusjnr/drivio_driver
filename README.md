# Drivio Driver

## Running flavors

| Flavor | Run |
|---|---|
| Staging (Beta) | `flutter run --flavor staging -t lib/main_stage.dart` |
| Production | `flutter run --flavor prod -t lib/main_prod.dart` |

Plain `flutter run` (no flavor) still works for quick dev and loads `.env`.
Env files: `.env.staging` / `.env.prod` (checked-in keys only — no secrets).

| Flavor | Android appId | iOS bundle ID | Name |
|---|---|---|---|
| prod | `com.drivedrivio.drivio_driver` | `com.drivedrivio.drivio-driver` | Drivio Driver |
| staging | `com.drivedrivio.drivio_driver.beta` | `com.drivedrivio.drivio-driver.beta` | Drivio Driver Beta |
