# Smart Waste Management & Recycling App

Flutter + Firebase + Google Maps. Three roles: **Citizen**, **Driver**, **Admin**.

## What's included
- Email auth; role-based routing (`users/{uid}.role`)
- Citizen: pickup request with map pin, date/slot, live status; complaints with photo + GPS + rating; recycling guide search, daily tip, reward points
- Driver: ordered stop list, Start / Done buttons
- Admin: all requests (assign driver, change status), resolve complaints, stats, one-tap route optimization (Routes API)
- Cloud Functions: push notifications, reward points, route optimization
- Firestore + Storage security rules

## Setup (one time)
1. **Create the platform folders** (this repo contains only the Dart code):
   ```bash
   flutter create . --project-name smart_waste_app
   flutter pub get
   ```
2. **Firebase**: create a project, enable *Authentication (Email/Password)*, *Firestore*, *Storage*. Then:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure        # generates lib/firebase_options.dart
   ```
3. **Android** (`android/app/build.gradle`): set `minSdk = 23`.
   In `android/app/src/main/AndroidManifest.xml` add inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   ```
   and inside `<application>`:
   ```xml
   <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_MAPS_ANDROID_KEY"/>
   ```
   **iOS**: add `NSLocationWhenInUseUsageDescription` and `NSCameraUsageDescription` to `Info.plist`, and call `GMSServices.provideAPIKey("KEY")` in `AppDelegate`.
4. **Google Cloud**: enable *Maps SDK for Android/iOS* and *Routes API*. Make two keys: an app key (restricted to your package name) and a server key for Functions.
5. **Deploy rules and functions** (Functions need the Blaze plan):
   ```bash
   cp functions/.env.example functions/.env   # fill in MAPS_KEY and depot coordinates
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,storage,functions
   ```
6. **Run**: `flutter run`

## Creating admin and driver accounts
Register normally in the app, then in Firebase Console → Firestore → `users/{uid}` change `role` to `admin` or `driver`. (Rules stop users from promoting themselves.)

## Demo flow
1. Citizen registers → requests a pickup.
2. Admin assigns a driver (status becomes *scheduled*) → taps the route icon to optimize.
3. Driver taps Start → Done.
4. Citizen gets a push notification and reward points.

## Notes
- Sorting is done client-side, so no composite Firestore indexes are needed.
- Never commit `.env`, API keys or `google-services.json`.
- Ideas to extend: Hindi/Punjabi localization, zone polygons, bin fill-level IoT, QR codes, Flutter Web admin build (`flutter build web`).
