If Android Studio reports that gradle-wrapper.jar is missing, run from the
Flutter project root:

flutter create . --platforms=android

Flutter will regenerate the standard Android wrapper/platform files while
preserving lib/main.dart and pubspec.yaml. Then run:

flutter pub get
flutter build apk --release
