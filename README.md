# 🌍 GeoFlow

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)](https://firebase.google.com/)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod-00d2ff.svg?style=for-the-badge)](https://riverpod.dev/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF.svg?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/MihirParmar011/GeoFlow-App/actions)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

**A Next-Generation Real-Time Dual-User Live Location Sharing, Navigation, and Routing Application built with Flutter, Riverpod, OpenStreetMap, and Firebase.**

[Features](#-key-features) • [Architecture](#-architecture) • [Getting Started](#-getting-started) • [Firebase Setup](#-firebase-configuration) • [CI/CD Deployment](#-cicd-pipeline)

</div>

---

## 📌 Overview

**GeoFlow** is a modern, privacy-conscious geospatial mobile application designed for real-time location collaboration, turn-by-turn routing, and interactive map exploration. Built on top of **OpenStreetMap**, **OSRM**, and **Firebase Firestore**, GeoFlow allows two or more connected users to share live location streams, view live telemetry (speed, altitude, accuracy, heading), search global destinations, and generate optimized driving routes.

---

## ✨ Key Features

### 📍 1. Real-Time Dual-User Location Sharing
- **Live Peer-to-Peer Tracking**: Stream live coordinates with sub-second latency powered by Cloud Firestore.
- **Connection Requests**: Securely request, accept, or decline location-sharing sessions with specific users or guest IDs.
- **Dynamic Live Telemetry**: Monitor partner distance, speed, altitude, accuracy, and heading orientation in real time.
- **Live Status Indicators**: Visual indicators showing connection state, background sync status, and battery-friendly throttled polling.

### 🗺️ 2. High-Performance Interactive Maps
- **OpenStreetMap Integration**: Fast, vector-like tile rendering powered by `flutter_map` and `latlong2`.
- **Multiple Map Layers & Themes**: Seamless switching between Dark, Light, and custom map styles.
- **Custom Map Widgets**: Integrated compass with rotation tracking, dynamic scale bar, and vehicle/partner markers.

### 🚗 3. Turn-by-Turn Routing & Directions
- **OSRM Routing Engine**: Fast, free routing powered by the Open Source Routing Machine API.
- **Route Information Overlay**: Real-time calculated driving distances (km/miles) and estimated time of arrival (ETA).
- **Interactive Route Polylines**: Smooth polyline overlays visualizing the entire journey path on the map.

### 🔍 4. Geocoding & Global Place Search
- **Nominatim API Integration**: Instant address search, place suggestions, and reverse geocoding with debounce handling.
- **Interactive Search Overlay**: Jump directly to search results on the map with a single tap.

### 🔐 5. Authentication & User Management
- **Firebase Authentication**: Support for email/password accounts and instant guest/anonymous sessions.
- **User Profiles**: Custom usernames, searchable user directories, and Firestore security rule enforcement.

### 🎨 6. Premium Glassmorphic UI/UX
- **Cyberpunk & Glassmorphic Design**: Modern dark theme with translucent glass panels, backdrop blurs, and neon cyan accents.
- **Smooth Micro-Animations**: Fluid transitions and dialog entrance animations powered by `flutter_animate`.
- **Localization**: Multi-language architecture configured with `easy_localization`.

---

## 🏗️ Architecture

GeoFlow adheres to **Feature-First Clean Architecture** principles for scalability, testability, and separation of concerns:

```
lib/
├── core/
│   └── theme/                       # App themes, color tokens, and ThemeProvider
├── features/
│   ├── auth/                        # Authentication feature
│   │   ├── domain/                  # Entities, user models, contracts
│   │   └── presentation/            # Auth screen and Riverpod auth providers
│   ├── location/                    # Real-time location engine
│   │   ├── domain/                  # Services (Permission, Sharing, Validation), Entities
│   │   └── presentation/            # Riverpod location sync & sharing providers
│   └── map/                         # Map, Search, and Routing feature
│       ├── data/                    # Nominatim & OSRM API datasources
│       ├── domain/                  # Place, Route, MapStyle entities
│       └── presentation/            # MapScreen, LiveLocationScreen, custom map widgets
├── firebase_options.dart            # FlutterFire auto-generated configuration
├── main.dart                        # Application bootstrap & dependency initialization
└── main_nav_screen.dart             # Glassmorphic bottom navigation & dialog handler
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.11.5` or latest stable)
- [Android Studio](https://developer.android.com/studio) / VS Code with Flutter extension
- [Java 17](https://adoptium.net/) (required for modern Gradle builds)
- A [Firebase Project](https://console.firebase.google.com/)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/MihirParmar011/GeoFlow-App.git
   cd GeoFlow-App
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   # Run in Debug mode
   flutter run

   # Build Release APK
   flutter build apk --release
   ```

---

## 🔥 Firebase Configuration

GeoFlow uses Firebase for Authentication and real-time Firestore database synchronization.

1. **Create a Firebase Project**: Create a new project in the [Firebase Console](https://console.firebase.google.com/).
2. **Add Android App**: Register your package name `com.example.geoflow`.
3. **Add `google-services.json`**: Place your downloaded `google-services.json` in `android/app/google-services.json`.
4. **Deploy Firestore Rules**: Deploy the project security rules from [firestore.rules](firestore.rules):
   ```bash
   firebase deploy --only firestore:rules
   ```

---

## 🔄 CI/CD Pipeline (GitHub Actions)

GeoFlow includes an automated CI/CD pipeline configured in `.github/workflows/firebase_distribution.yml`:

- **Automatic Build**: On every push to `main` / `master` or manual `workflow_dispatch`, GitHub Actions builds the release APK (`flutter build apk --release`).
- **Artifact Upload**: Generates and uploads the `release-apk` artifact directly downloadable from the GitHub Actions run.
- **Firebase App Distribution**: Automatically distributes release builds to tester groups if `FIREBASE_SERVICE_ACCOUNT_KEY` secret is configured in your GitHub repository secrets.

### GitHub Secrets Setup

To enable automated Firebase App Distribution:
| Secret Name | Description |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Private JSON key content for Google Service Account with `Firebase App Distribution Admin` role |
| `FIREBASE_APP_ID` | *(Optional)* Android App ID (e.g. `1:1011942886407:android:a9d46be3a6f3c7e2662ea2`) |
| `FIREBASE_TESTER_GROUPS` | *(Optional)* Tester group name in Firebase Console (default: `testers`) |

---

## 📦 Tech Stack & Dependencies

| Category | Technology / Package | Purpose |
|---|---|---|
| **Framework** | [Flutter](https://flutter.dev) | Cross-platform UI toolkit |
| **Language** | [Dart](https://dart.dev) | Modern typed language |
| **State Management** | [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) | Reactive, compile-safe state management |
| **Maps** | [`flutter_map`](https://pub.dev/packages/flutter_map) + [`latlong2`](https://pub.dev/packages/latlong2) | OpenStreetMap tile rendering |
| **Geolocation** | [`geolocator`](https://pub.dev/packages/geolocator) | High-accuracy GPS & background position streams |
| **Routing** | [OSRM API](https://project-osrm.org/) | Turn-by-turn polyline generation and ETA |
| **Search** | [Nominatim API](https://nominatim.org/) | Global geocoding and address search |
| **Backend & Sync** | [`cloud_firestore`](https://pub.dev/packages/cloud_firestore) | Sub-second realtime location synchronization |
| **Auth** | [`firebase_auth`](https://pub.dev/packages/firebase_auth) | User & anonymous guest authentication |
| **Localization** | [`easy_localization`](https://pub.dev/packages/easy_localization) | Internationalization & multi-language support |
| **Animations** | [`flutter_animate`](https://pub.dev/packages/flutter_animate) | Micro-interactions and fluid transitions |

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<div align="center">
  <sub>Built with ❤️ using Flutter & OpenStreetMap</sub>
</div>
