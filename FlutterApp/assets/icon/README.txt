Place your app icon images here:

- app_icon.png (1024x1024 recommended, square, no transparency for iOS store compliance)
- app_icon_foreground.png (for Android adaptive icon foreground, transparent background)

After copying the images, run:

PowerShell:
  flutter pub get
  flutter pub run flutter_launcher_icons -f pubspec.yaml

Notes:
- The background color for Android adaptive icon is set to #0D47A1 in pubspec.yaml.
- You can change image paths or colors under the `flutter_launcher_icons` section.
