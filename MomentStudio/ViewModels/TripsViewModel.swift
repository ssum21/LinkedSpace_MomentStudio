//
//  TripsViewModel.swift
//  MomentStudio
//
//  Created by SSUM on 7/29/25.
//
//  PURPOSE: Manages the state and business logic for the TripsView. It orchestrates the
//           entire photo analysis pipeline, from fetching photos to creating albums,
//           and provides real-time feedback to the UI.
//

import SwiftUI
import Photos
import CoreML

@MainActor
class TripsViewModel: ObservableObject {
    
    // MARK: - PUBLISHED PROPERTIES
    
    /// The final list of generated trip albums. The UI observes this property to display results.
    @Published var trips: [TripAlbum] = []
    
    /// A boolean flag to indicate if a long-running analysis task is in progress.
    @Published var isLoading = false
    
    /// A user-facing string that describes the current status of the analysis.
    @Published var statusMessage = "Ready to find your trips."
    
    /// A value from 0.0 to 1.0 representing the progress of the photo processing stage.
    @Published var progress: Double = 0.0

    // MARK: - DEPENDENCIES
    
    private let tripDetector = TripDetectorService()
    private let mobileCLIPClassifier: ZSImageClassification
    private var albumService: AlbumCreationService

    // MARK: - INITIALIZATION
    
    init() {
        // 1. Initialize all necessary service dependencies.
        let classifier = ZSImageClassification(model: defaultModel.factory())
        self.mobileCLIPClassifier = classifier
        let engine = POIRankingEngine(classifier: classifier)
        self.albumService = AlbumCreationService(rankingEngine: engine, classifier: classifier)
        
        // 2. Connect the AlbumCreationService's status updater to this ViewModel.
        // This allows the service to send detailed progress messages back to the UI.
        self.albumService.statusMessageUpdater = { [weak self] message in
            DispatchQueue.main.async {
                self?.statusMessage = message
            }
        }
        
        // 3. Asynchronously pre-load the CoreML models for faster performance later.
        Task {
            await mobileCLIPClassifier.load()
        }
        
        // 4. When the app starts, immediately try to load any albums from the last session.
        loadTripsFromCache()
    }
    
    
    /// Loads previously generated albums from the local cache.
    func loadTripsFromCache() {
        guard let cachedAlbums = AlbumCacheManager.load(), !cachedAlbums.isEmpty else {
            statusMessage = "Press the button to find your trips."
            return
        }
        self.trips = cachedAlbums
        self.statusMessage = "Loaded \(cachedAlbums.count) trips from your last session."
    }
    
    /// The main function to run the full photo analysis pipeline, triggered by a user action.
    func generateNewTrips() async {
        guard !isLoading else { return }

        // --- Step 1: Initial UI State Setup ---
        isLoading = true
        trips = []
        progress = 0.0
        statusMessage = "Clearing previous cache..."
        AlbumCacheManager.clearCache()
        
        // --- Step 2: Check Permissions ---
        statusMessage = "Checking photo library access..."
        guard await requestPhotoLibraryAccess() else {
            await finish(with: "Photo library access is required to find trips."); return
        }
        
        // --- Step 3: Find Assets ---
        statusMessage = "Finding recent photos..."
        let sortedAssets = await findAssetsWithLocation()
        guard !sortedAssets.isEmpty else {
            await finish(with: "No recent photos with location data found to analyze."); return
        }

        // --- Step 4: Process Assets (Generate Embeddings) ---
        let photoAssets = await processAssets(sortedAssets)
        guard !photoAssets.isEmpty else {
            await finish(with: "Could not process photos for analysis."); return
        }
        
        // --- Step 5: Detect Trips ---
        statusMessage = "Detecting trips from your photos..."
        let tripDataSets = tripDetector.detectTrips(from: photoAssets)
        if tripDataSets.isEmpty {
            await finish(with: "No distinct trips were found in your recent photos."); return
        }
        
        // --- Step 6: Create Albums for Each Trip ---
        var finalAlbums: [TripAlbum] = []
        for (_, tripData) in tripDataSets.enumerated() {
            // The status message will now be updated by the albumService directly.
            // e.g., "Step 1/3: Finding Moments..."
            do {
                if let album = try await albumService.createAlbum(from: tripData), !album.days.isEmpty {
                    finalAlbums.append(album)
                }
            } catch {
                print("Error creating an album for a trip: \(error.localizedDescription)")
            }
        }
        
        // --- Step 7: Finalize and Save ---
        trips = finalAlbums
        AlbumCacheManager.save(albums: finalAlbums)
        await finish(with: "Successfully created \(finalAlbums.count) new trip albums!")
    }
    
    // MARK: - PRIVATE HELPERS
    
    /// A centralized function to update the final status and reset the loading state.
    private func finish(with message: String) async {
        statusMessage = message
        isLoading = false
        progress = 0.0
    }

    private func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    private func findAssetsWithLocation() async -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 150 // Analyze the 150 most recent photos
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assetsWithLocation: [PHAsset] = []
        fetchResult.enumerateObjects { (asset, _, _) in
            if asset.location != nil {
                assetsWithLocation.append(asset)
            }
        }
        // Clustering requires photos to be sorted from oldest to newest.
        return assetsWithLocation.sorted { $0.creationDate! < $1.creationDate! }
    }

    private func processAssets(_ assets: [PHAsset]) async -> [PhotoAsset] {
        var processedAssets: [PhotoAsset] = []
        let totalCount = assets.count
        
        for (index, asset) in assets.enumerated() {
            guard let location = asset.location, let creationDate = asset.creationDate else { continue }
            
            // Update local progress properties for the UI.
            self.progress = Double(index + 1) / Double(totalCount)
            self.statusMessage = "Analyzing photo \(index + 1) of \(totalCount)..."
            
            let embedding = await getEmbedding(for: asset)
            let photoAsset = PhotoAsset(id: asset.localIdentifier, asset: asset, location: location, creationDate: creationDate, imageEmbedding: embedding)
            processedAssets.append(photoAsset)
        }
        return processedAssets
    }

    private func getEmbedding(for asset: PHAsset) async -> MLMultiArray? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 256, height: 256), contentMode: .aspectFill, options: options) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    print("Image Request Error: \(error.localizedDescription) for asset \(asset.localIdentifier)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let image = image, let pixelBuffer = image.toCVPixelBuffer() else {
                    continuation.resume(returning: nil)
                    return
                }
                Task {
                    let result = await self.mobileCLIPClassifier.computeImageEmbeddings(frame: pixelBuffer)
                    continuation.resume(returning: result?.embedding)
                }
            }
        }
    }
}
