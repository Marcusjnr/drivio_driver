#!/bin/bash
# Script to generate Firebase configuration files for different environments/flavors
# Feel free to reuse and adapt this script for your own projects

if [[ $# -eq 0 ]]; then
  echo "Error: No environment specified. Use 'stage', or 'prod'."
  exit 1
fi

case $1 in
  stage)
    flutterfire config \
      --project=drivio-staging \
      --out=lib/firebase_options_stage.dart \
      --ios-bundle-id=com.example.drivioDriver \
      --ios-out=ios/flavors/stage/GoogleService-Info.plist \
      --android-package-name=com.example.drivio_driver \
      --android-out=android/app/src/stage/google-services.json
    ;;
  prod)
    flutterfire config \
      --project=foodie-user-prodution \
      --out=lib/firebase_options_prod.dart \
      --ios-bundle-id=ng.foodie.user.foodieUserMobileAppInterface \
      --ios-out=ios/flavors/prod/GoogleService-Info.plist \
      --android-package-name=ng.foodie.user.foodie_user_mobile_app_interface \
      --android-out=android/app/src/prod/google-services.json
    ;;
  *)
    echo "Error: Invalid environment specified. Use 'stage', or 'prod'."
    exit 1
    ;;
esac