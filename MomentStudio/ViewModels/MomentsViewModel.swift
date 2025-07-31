//
//  MomentsViewModel.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Manages the "All Moments" feed, and includes the on-demand POI
//           ranking logic to allow editing moments directly from the feed.
//

import SwiftUI
import MapKit
import Photos

@MainActor
class MomentsViewModel: ObservableObject {
    
    // MARK: - PUBLISHED PROPERTIES
    
    @Published var allMoments: [Moment] = []
    @Published var statusMessage: String = "Loading moments..."
    
    // For the POI ranking process
    @Published var isRanking: Bool = false
    @Published var rankingError: String?
    @Published var momentToEdit: Binding<Moment>?
    @Published var showPOIChooser: Bool = false
    
    // MARK: - DEPENDENCIES
    
    private let rankingEngine: POIRankingEngine
    private let mobileCLIPClassifier: ZSImageClassification

    // MARK: - INITIALIZATION
    
    init() {
        let classifier = ZSImageClassification(model: defaultModel.factory())
        self.mobileCLIPClassifier = classifier
        self.rankingEngine = POIRankingEngine(classifier: classifier)
        
        loadAllMomentsFromCache()
    }
    
    // MARK: - DATA LOADING & SAVING
    
    func loadAllMomentsFromCache() {
        self.statusMessage = "Finding all your moments..."
        
        guard let allTrips = AlbumCacheManager.load(), !allTrips.isEmpty else {
            self.statusMessage = "No moments found. Create a trip in the 'Trips' tab first!"
            self.allMoments = []
            return
        }
        
        let moments = allTrips.flatMap { $0.days.flatMap { $0.moments } }
        
        // A more robust date sorting will be needed if time strings are not uniform.
        self.allMoments = moments.sorted(by: { $0.time > $1.time })
        
        if self.allMoments.isEmpty {
            self.statusMessage = "No moments found in your generated trips."
        }
    }
    
    func saveMomentsToCache() {
        // TODO: Implement a more sophisticated saving mechanism.
        // This would require finding the original trip in the cache, updating the specific
        // moment, and then re-saving the entire trips array.
        print("INFO: A moment was updated. Logic to save changes back to AlbumCacheManager is needed.")
    }
    
    // MARK: - POI RANKING LOGIC
    
    func rankPOIs(for momentBinding: Binding<Moment>) async {
        self.isRanking = true
        self.momentToEdit = momentBinding
        let moment = momentBinding.wrappedValue
        
        guard let imagePixelBuffer = await getPixelBuffer(for: moment.representativeAssetId),
              let photoCoordinate = getCoordinate(for: moment.representativeAssetId)
        else {
            self.rankingError = "Could not prepare the photo for analysis."; self.isRanking = false; return
        }
        
        let placesService = GooglePlacesAPIService()
        let placesToRank = (try? await placesService.fetchAndCategorizePlaces(for: photoCoordinate).map { $0.place }) ?? []
        
        guard !placesToRank.isEmpty else {
            self.rankingError = "No nearby places found."; self.isRanking = false; return
        }
        
        let ranked = await rankingEngine.rankPlaces(
            places: placesToRank, imagePixelBuffer: imagePixelBuffer, photoLocation: photoCoordinate
        )
        
        guard !ranked.isEmpty else {
            self.rankingError = "Could not find any suitable candidates."; self.isRanking = false; return
        }
        
        let newCandidates = ranked.map {
            POICandidate(id: $0.place.placeId, name: $0.place.name, score: $0.finalScore, latitude: $0.place.location.lat, longitude: $0.place.location.lng)
        }
        
        momentBinding.wrappedValue.poiCandidates = newCandidates
        
        self.isRanking = false
        self.showPOIChooser = true
    }
    
    // MARK: - HELPER FUNCTIONS
    
    /// Asynchronously retrieves a CVPixelBuffer for a given asset ID.
    private func getPixelBuffer(for assetId: String) async -> CVPixelBuffer? {
        guard let image = await getHighQualityImage(for: assetId) else { return nil }
        // Assumes a UIImage extension `toCVPixelBuffer()` exists.
        return image.toCVPixelBuffer()
    }
    
    /// Asynchronously retrieves a high-quality UIImage for a given asset ID from the Photo Library.
    private func getHighQualityImage(for assetId: String) async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none // Request original size
        options.isNetworkAccessAllowed = true // Allow downloading from iCloud
        
        return await withCheckedContinuation { continuation in
            // Request the image data. The result handler may be called multiple times;
            // we are interested in the final, high-quality image.
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
                // Check if this is the final, full-quality image.
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, !isDegraded {
                    continuation.resume(returning: image)
                } else if image != nil && info == nil {
                    // Sometimes for local images, info is nil. If we have an image, use it.
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Retrieves the geographic coordinate for a given asset ID.
    private func getCoordinate(for assetId: String) -> CLLocationCoordinate2D? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        return fetchResult.firstObject?.location?.coordinate
    }
}
