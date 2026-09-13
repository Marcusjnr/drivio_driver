MANIFEST_DIR                     = .manifests

$(shell mkdir -p $(MANIFEST_DIR))

$(MANIFEST_DIR)/mobile-dependencies: pubspec.yaml pubspec.lock
	flutter pub get

get:
	fvm flutter pub get

generate:
	fvm dart run build_runner build --delete-conflicting-outputs

build-stage-android:
	fvm flutter build apk -t lib/main_stage.dart --profile

build-preprod-android:
	fvm flutter build apk -t lib/main_preprod.dart --flavor preprod --profile

build-prod-android:
	fvm flutter build apk -t lib/main_prod.dart --flavor prod --profile

build-prod-android-release:
	fvm flutter build appbundle -t lib/main_prod.dart --flavor prod --release

build-prod-ios-release:
	fvm flutter build ios -t lib/main_prod.dart --flavor prod --release

test:
	fvm flutter test