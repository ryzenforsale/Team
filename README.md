#  MeetMe: High-Precision Proximity Tracker

**MeetMe** is a Flutter-based mobile application designed to solve the problem of finding friends in crowded or indoor environments. By combining traditional GPS with Bluetooth Low Energy (BLE) and advanced Pedestrian Dead Reckoning (PDR), MeetMe provides a buttery-smooth, highly accurate directional arrow and distance tracker—even in concrete buildings where standard GPS fails.

---

##  Key Features

* **Hybrid Distance Engine**: Seamlessly falls back from global GPS tracking to highly precise Bluetooth Low Energy (BLE) RSSI triangulation when within 20 meters.
* **Stable Directional Arrow (PDR)**: Uses the smartphone's built-in IMU sensors (accelerometer & compass) via Pedestrian Dead Reckoning. This prevents the arrow from wildly spinning while standing still indoors.
* **Real-time Connection Flow**: Send and receive persistent connection requests powered by Firebase Realtime Database.
* **Immersive Proximity UI**: As you get within 5 meters of your friend, the UI transitions to a radar-pulse interface with haptic feedback vibrations and auditory beeps.

---

##  Technology Stack

* **Framework:** Flutter (Dart)
* **Backend:** Firebase (Authentication, Realtime Database)
* **Sensors:** 
  * `geolocator` (Outdoor macro-tracking)
  * `flutter_blue_plus` & `flutter_ble_peripheral` (Indoor micro-tracking)
  * `sensors_plus` & `flutter_compass` (Inertial dead reckoning)

---

##  Prerequisites & Dependencies
Before you run this project, make sure you have the following installed:

* Flutter SDK (compatible with dart 3.0+)
* Android Studio (for Android toolchain and SDKs)
* Android Device with Android 12+ (Physical device recommended. Emulators **cannot** test Bluetooth or Accelerometer accurately).

---

##  Getting Started

Follow these steps to run the project locally.

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/meetme.git
cd meetme/meet_me
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Firebase Configuration
This project uses Firebase. You must provide your own `google-services.json` file to run it locally.
1. Create a Firebase Project in the [Firebase Console](https://console.firebase.google.com/).
2. Register an Android app using the package name exactly as it appears in this project's `build.gradle` (e.g. `com.example.meet_me`).
3. Enable **Authentication** (Anonymous/Email) and **Realtime Database**.
4. Download the `google-services.json` file and place it inside the `android/app/` directory.

### 4. Build and Run
Because this app relies heavily on hardware sensors (Bluetooth and IMU), **you must run it on a physical smartphone**.

Connect your Android phone via USB and run:
```bash
flutter run
```
*(Note: Android will prompt you for Location, Bluetooth, and Nearby Devices permissions upon opening the app).*

---

##  Architecture Highlight: Solving the "Indoor Jitter"

Traditional tracking apps suffer from "Multipath Interference" indoors, causing coordinates to jump wildly and rendering directional arrows useless. 
**MeetMe solves this in two layers:**
1. **Distance**: Once you are in the same room, MeetMe's `BleService` takes over, converting Bluetooth radio signal strength directly into physical meters, bypassing global satellites completely.
2. **Direction**: MeetMe's `DeadReckoningService` anchors the device at the last "good" GPS reading and relies strictly on physical accelerometer readings. If you step 1 meter North physically, the app pushes exactly 1 unit North mathematically.

---

##  Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## 📝 License
[MIT](https://choosealicense.com/licenses/mit/)