# 📸 MomentStudio (in LinkedSpace Function)

**MomentStudio** is an intelligent iOS photo album application that automatically groups your photos into memorable trips and moments. Using the power of Core ML's CLIP model and location-based clustering, it transforms your photo library into a structured and engaging travel diary.

This project was developed by combining a functional Swift backend with a new, intuitive UI designed in Figma.

---

## ✨ Key Features

-   **Automatic Trip Creation:** Automatically detects and groups photos into distinct trips based on time and location gaps.
-   **Intelligent Moment Clustering:** Within each trip, photos are clustered into "Moments" representing visits to specific places or events.
-   **AI-Powered Place Recognition:** Leverages the MobileCLIP model and Google Places API to intelligently rank and identify the name of the place for each moment.
-   **Interactive Map Editing:** Users can edit a moment's location by choosing from the top 7 AI-ranked candidates, visualized on an interactive map.
-   **Live Camera Capture:** Capture new moments directly within the app, with GPS data automatically embedded for future album creation.
-   **Chronological Moment Feed:** An "All Moments" tab provides a clean, scrollable feed of every moment from all your trips, sorted chronologically.

---

## 🛠️ Tech Stack & Architecture

-   **UI Framework:** SwiftUI
-   **Architecture:** Model-View-ViewModel (MVVM)
-   **Core Technologies:**
    -   **Core ML:** For on-device image and text embedding using the `MobileCLIP-S2` model.
    -   **Photos Framework:** For fetching and saving images from the user's photo library.
    -   **MapKit:** For displaying interactive maps for location selection.
    -   **CoreLocation:** For handling GPS data.
    -   **Google Places API:** For fetching nearby place candidates for ranking.
-   **Concurrency:** Modern Swift Concurrency (`async/await`, `Task`).

The app follows a unidirectional data flow within the `Trips` navigation stack, primarily using `@StateObject`, `@ObservedObject`, and `@Binding` for robust state management.

---

## 📂 Project Structure

The project is organized into logical groups to maintain a clean and scalable codebase.

```
/MomentStudio
├── 📁 Application         # App entry point, MainTabView, and global state (AppState)
├── 📁 Core                # Core ML models (.mlpackage) and CameraController
├── 📁 Models              # Core data structures (TripAlbum, Day, Moment, PhotoAsset)
├── 📁 Resources           # Vocabulary files for the CLIP Tokenizer
├── 📁 Services            # Business logic, decoupled from the UI
│   ├── 📁 AlbumCreation   # The main engine for creating albums
│   ├── 📁 Cache            # Handles local caching of generated albums
│   ├── 📁 Clustering       # DBSCAN and other clustering algorithms
│   └── 📁 POI              # Google Places API service and the POI Ranking Engine
├── 📁 Tokenizer           # Swift implementation of the CLIP Tokenizer
├── 📁 ViewModels          # Manages state and logic for each main view
└── 📁 Views               # All SwiftUI views, organized by feature
    ├── 📁 Capture          # Camera UI
    ├── 📁 Moments          # "All Moments" feed and map-based POI chooser
    └── 📁 Trips            # Main trips list and detail views
```

---

## 🚀 Getting Started

To run this project, you will need to configure your own API keys.

### Prerequisites

-   Xcode 15.0 or later
-   iOS 17.0 or later
-   An Apple Developer account to run on a physical device (required for camera and photo library access)

### Setup

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/ssum21/LinkedSpace_MomentStudio.git
    ```

2.  **Configure API Key:**
    -   Obtain a **Google Places API** key from the [Google Cloud Platform](https://console.cloud.google.com/). Make sure the "Places API" is enabled for your project and a billing account is linked.
    -   In the Xcode project, open the `Info.plist` file.
    -   Add a new key named `GOOGLE_API_KEY`.
    -   Paste your API key as the value for this key.

3.  **Build and Run:**
    -   Open `MomentStudio.xcodeproj` in Xcode.
    -   Select your target device (a physical device is recommended).
    -   Run the app (`Cmd + R`).

The first time you navigate to the "Trips" or "Capture" tabs, the app will ask for permission to access your photo library and camera.

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
