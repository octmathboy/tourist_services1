# 🗺️ Tourist Services (`tourist_services1`)

A Flutter application that helps tourists and locals discover nearby landmarks, places of worship, excursion tours, and essential services in real-time based on their live GPS location.

---

## 📸 Demo & Preview

> *Add a GIF or screenshot of your app running here!*  
`![App Demo](assets/demo.gif)`

---

## ✨ Features

* 📡 **Live GPS Tracking:** Uses device location services (`geolocator`) to fetch precise real-time coordinates.
* 📏 **Dynamic Distance Calculation:** Calculates distances in both **Kilometers** and **Miles** on-the-fly using the Haversine formula.
* 🎯 **50 km Proximity Filter:** Automatically filters out locations outside a 50 km radius.
* ↕️ **Smart Proximity Sorting:** Automatically orders places from nearest to farthest.
* 🕌 **Places of Worship:** Tabbed navigation separating **Islamic** (Mosques) and **Christian** (Churches & Cathedrals) sites.
* 🚖 **Local Services & Tours:** Category-based discovery for transport/taxis, hotels, restaurants, and guided excursion tours.
* 🧭 **One-Tap Actions:** Direct integrations with **Google Maps** for route navigation and device dialing for phone calls via `url_launcher`.

---

## 🛠️ Tech Stack & Packages

| Tech / Library | Purpose |
| :--- | :--- |
| **Flutter / Dart** | Cross-platform UI development framework |
| **Firebase Firestore** | Real-time backend database for places & services |
| **`geolocator`** | Fetching device GPS position and managing location permissions |
| **`url_launcher`** | Opening external map routes and triggering direct phone calls |

---

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (`>=3.0.0`)
* Android Studio / Xcode configured with an emulator or physical device.

### Installation

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/tourist_services1.git](https://github.com/your-username/tourist_services1.git)
   cd tourist_services1

