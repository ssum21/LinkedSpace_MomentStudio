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

## 🛠️ Setup Instructions

To build and run this project, you will need to perform a few manual setup steps to include the required machine learning models and API keys, which are not checked into the Git repository.

### Prerequisites

- macOS with Xcode 15 or later
- A Google Cloud Platform account with the **Places API** enabled.

### Step 1: Clone the Repository

First, clone the repository to your local machine.

```bash
git clone https://github.com/ssum21/LinkedSpace_MomentStudio.git
cd LinkedSpace_MomentStudio
```

### Step 2: Download the Core ML Models

This project relies on large Core ML model files (`.mlpackage`) that are excluded from this repository. You need to download them from the original Apple `ml-mobileclip` repository and place them in the correct directory.

1.  Navigate to the official Apple MobileCLIP repository: [https://github.com/apple/ml-mobileclip](https://github.com/apple/ml-mobileclip)
2.  Download the following model packages:
    - `mobileclip_s2_image.mlpackage`
    - `mobileclip_s2_text.mlpackage`
3.  Place these two downloaded `.mlpackage` folders inside the **`MomentStudio/Core/`** directory in your local project.

After this step, your `MomentStudio/Core/` directory should look like this in the Xcode project navigator:

```
└── Core/
    ├── AsyncFactory.swift
    ├── CameraController.swift
    ├── mobileclip_s2_image.mlpackage  <-- ADDED
    ├── mobileclip_s2_text.mlpackage   <-- ADDED
    └── Models.swift
```

### Step 3: Configure Environment Variables (Google API Key)

The app uses the Google Places API to fetch information about nearby locations. You must provide your own API key.

1.  In Xcode, right-click on the `MomentStudio` group (the root folder) and select **New File...**.
2.  Choose the **Property List** template and click Next.
3.  Name the file **`secrets.plist`** and make sure it is added to the `MomentStudio` target.
4.  Open the newly created `secrets.plist` file and add a new row with the following information:
    - **Key:** `GOOGLE_API_KEY`
    - **Type:** `String`
    - **Value:** `Your_Actual_Google_Places_API_Key`

The contents of your `secrets.plist` file should look like this:



> **Important:** The `.gitignore` file is configured to ignore `secrets.plist`, so your private key will not be accidentally committed to the repository.

### Step 4: Build and Run

You are all set! Open `MomentStudio.xcodeproj` in Xcode and build and run the project on a simulator or a physical device. The app should now compile and run successfully.


---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
