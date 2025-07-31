//
//  AlbumCreationService.swift
//  MomentStudio
//
//  Created by SSUM on 7/28/25.
//
//  PURPOSE: The core engine for creating trip albums. This service takes a collection of
//           photos from a single trip and orchestrates a multi-level clustering process
//           to structure them into a meaningful album with days, moments, and highlights.
//

import Foundation
import CoreLocation
import Vision
import Photos
import UIKit
import CoreML

@MainActor
class AlbumCreationService {

    // MARK: - Dependencies & Properties
    
    private let rankingEngine: POIRankingEngine
    private let mobileCLIPClassifier: ZSImageClassification
    
    /// A closure to update the status message on the UI. The ViewModel will set this.
    var statusMessageUpdater: ((String) -> Void)?

    // MARK: - Clustering Parameters
    
    /// [Level 2] The maximum distance (in meters) for photos to be considered part of the same Moment.
    private let spatialThreshold: CLLocationDistance = 175.0
    
    /// [Level 2] The maximum time gap (in seconds) for photos to be considered part of the same Moment.
    private let temporalThreshold: TimeInterval = 3 * 60 * 60 // 3 hours
    
    /// [Level 3] The minimum similarity score for photos to be grouped into the same Highlight.
    private let highlightSimilarityThreshold: Float = 0.85

    // MARK: - Initialization
    
    init(rankingEngine: POIRankingEngine, classifier: ZSImageClassification) {
        self.rankingEngine = rankingEngine
        self.mobileCLIPClassifier = classifier
    }

    // MARK: - Main Execution Flow
    
    /// The primary function to create a complete TripAlbum from a set of photos.
    /// - Parameter photoAssets: An array of `PhotoAsset` objects, pre-sorted by creation date.
    /// - Returns: A fully structured `TripAlbum`, or `nil` if no valid album could be created.
    func createAlbum(from photoAssets: [PhotoAsset]) async throws -> TripAlbum? {
        // Level 2: Cluster photos into "Moments" based on time and location.
        statusMessageUpdater?("Step 1/3: Grouping photos into moments...")
        let momentClusters = performMomentClustering(on: photoAssets)
        guard !momentClusters.isEmpty else { return nil }
        
        // For each Moment, identify its Point of Interest (POI) name.
        statusMessageUpdater?("Step 2/3: Analyzing places...")
        for (index, cluster) in momentClusters.enumerated() {
            // Provide more detailed progress for this long-running step.
            statusMessageUpdater?("Analyzing place \(index + 1) of \(momentClusters.count)...")
            await identifyPOIName(for: cluster)
        }
        
        // Level 3: Structure the final album, creating "Highlights" within each Moment.
        statusMessageUpdater?("Step 3/3: Creating highlights and finishing up...")
        let album = generateAlbumStructure(from: momentClusters)
        
        return album
    }

    // MARK: - Level 2: Moment Clustering (Place/Event)
    
    private func performMomentClustering(on sortedAssets: [PhotoAsset]) -> [PhotoCluster] {
        var clusters: [PhotoCluster] = []
        guard let firstAsset = sortedAssets.first else { return [] }
        
        var currentCluster = PhotoCluster(initialAsset: firstAsset)
        clusters.append(currentCluster)
        
        for asset in sortedAssets.dropFirst() {
            let distance = asset.location.distance(from: currentCluster.representativeLocation)
            let timeDifference = asset.creationDate.timeIntervalSince(currentCluster.endTime)

            if distance < spatialThreshold && timeDifference < temporalThreshold {
                currentCluster.add(asset: asset)
            } else {
                currentCluster = PhotoCluster(initialAsset: asset)
                clusters.append(currentCluster)
            }
        }
        return clusters.filter { !$0.photoAssets.isEmpty }
    }
    
    private func identifyPOIName(for cluster: PhotoCluster) async {
        guard let coverAsset = cluster.coverAsset,
              let image = await getHighQualityImage(for: coverAsset.asset),
              let pixelBuffer = image.toCVPixelBuffer() else {
            cluster.identifiedPOIName = "Unknown Place"
            return
        }

        let photoCoordinate = coverAsset.location.coordinate
        let placesService = GooglePlacesAPIService()

        do {
            let categorizedPlaces = try await placesService.fetchAndCategorizePlaces(for: photoCoordinate)
            let placesToRank = categorizedPlaces.map { $0.place }
            
            guard !placesToRank.isEmpty else {
                cluster.identifiedPOIName = "No Nearby Places"
                return
            }
            
            let rankedCandidates = await rankingEngine.rankPlaces(
                places: placesToRank,
                imagePixelBuffer: pixelBuffer,
                photoLocation: photoCoordinate
            )
            
            if let bestCandidate = rankedCandidates.first {
                cluster.identifiedPOIName = bestCandidate.place.name
                cluster.poiCandidates = Array(rankedCandidates.prefix(8))
            } else {
                
                // 1. 사진의 위치를 CLLocation 객체로 만듭니다.
                let photoCLLocation = CLLocation(latitude: photoCoordinate.latitude, longitude: photoCoordinate.longitude)
                
                // 2. min(by:) 클로저를 올바른 문법으로 수정합니다.
                let closestPlace = placesToRank.min(by: { place1, place2 -> Bool in
                    // 3. 각 Place의 Location을 CLLocation으로 변환합니다.
                    let location1 = CLLocation(latitude: place1.location.lat, longitude: place1.location.lng)
                    let location2 = CLLocation(latitude: place2.location.lat, longitude: place2.location.lng)
                    
                    // 4. 사진 위치로부터의 거리를 각각 계산하여 비교합니다.
                    return location1.distance(from: photoCLLocation) < location2.distance(from: photoCLLocation)
                })
                
                // 5. 가장 가까운 장소의 이름을 사용하고, 없으면 기본값을 사용합니다.
                cluster.identifiedPOIName = closestPlace?.name ?? "A Nice Place"
                cluster.poiCandidates = [] // 순위 후보가 없으므로 비워둡니다.
            }
        } catch {
            print("Error identifying POI name: \(error)")
            cluster.identifiedPOIName = "Place Search Failed"
        }
    }
    
    // MARK: - Level 3: Highlight Clustering (Similar Photos)

    private func createHighlights(from assets: [PhotoAsset]) -> (highlights: [Highlight], optionals: [PhotoAsset]) {
        guard !assets.isEmpty else { return ([], []) }

        var tempClusters: [[PhotoAsset]] = []
        
        for asset in assets {
            guard let assetEmbedding = asset.imageEmbedding else { continue }
            
            var bestMatchIndex: Int? = nil
            var maxSimilarity: Float = 0.0

            for (index, cluster) in tempClusters.enumerated() {
                guard let representativeAsset = cluster.first, let repEmbedding = representativeAsset.imageEmbedding else { continue }
                let similarity = mobileCLIPClassifier.cosineSimilarity(assetEmbedding, repEmbedding)
                
                if similarity > highlightSimilarityThreshold && similarity > maxSimilarity {
                    maxSimilarity = similarity
                    bestMatchIndex = index
                }
            }

            if let index = bestMatchIndex {
                tempClusters[index].append(asset)
            } else {
                tempClusters.append([asset])
            }
        }
        
        var finalHighlights: [Highlight] = []
        var optionalAssets: [PhotoAsset] = []

        for cluster in tempClusters {
            guard let representative = cluster.first else { continue }
            
            if cluster.count > 1 {
                let ids = cluster.map { $0.id }
                let highlight = Highlight(representativeAssetId: representative.id, assetIds: ids)
                finalHighlights.append(highlight)
            } else {
                optionalAssets.append(representative)
            }
        }
        
        optionalAssets.sort { $0.creationDate < $1.creationDate }
        
        return (highlights: finalHighlights, optionals: optionalAssets)
    }

    // MARK: - Final Album Structuring

    private func generateAlbumStructure(from momentClusters: [PhotoCluster]) -> TripAlbum? {
        let groupedByDate = Dictionary(grouping: momentClusters) { cluster -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: cluster.startTime)
        }

        var albumDays: [Day] = []
        let sortedDates = groupedByDate.keys.sorted()

        for dateString in sortedDates {
            guard let clustersForDay = groupedByDate[dateString], !clustersForDay.isEmpty else { continue }
            
            let moments: [Moment] = clustersForDay.compactMap { cluster in
                guard let name = cluster.identifiedPOIName, let repAsset = cluster.coverAsset else { return nil }
                
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                let time = timeFormatter.string(from: cluster.startTime)
                
                let (highlights, optionalAssets) = createHighlights(from: cluster.photoAssets)
                
                guard !highlights.isEmpty || !optionalAssets.isEmpty else { return nil }
                
                let poiCandidates = cluster.poiCandidates.map { rankedCandidate -> POICandidate in
                    return POICandidate(
                        id: rankedCandidate.place.placeId,
                        name: rankedCandidate.place.name,
                        score: rankedCandidate.finalScore,
                        latitude: rankedCandidate.place.location.lat,
                        longitude: rankedCandidate.place.location.lng
                    )
                }

                return Moment(
                    name: name,
                    time: time,
                    representativeAssetId: repAsset.id,
                    highlights: highlights,
                    optionalAssetIds: optionalAssets.map { $0.id },
                    poiCandidates: poiCandidates
                )
            }
            
            guard !moments.isEmpty else { continue }

            let coverImageIdentifier = moments.first?.representativeAssetId ?? ""
            let summary = moments.map { $0.name }.prefix(3).joined(separator: ", ") + " & more"
            
            let day = Day(date: dateString, coverImage: coverImageIdentifier, summary: summary, moments: moments)
            albumDays.append(day)
        }
        
        guard !albumDays.isEmpty else { return nil }
        
        let albumTitle = generateLandmarkAlbumTitle(from: albumDays)
        return TripAlbum(albumTitle: albumTitle, days: albumDays)
    }
    
    private func generateLandmarkAlbumTitle(from days: [Day]) -> String {
        // 모든 모먼트의 모든 POI 후보군을 하나로 합침
        let allCandidates = days.flatMap { $0.moments }.flatMap { $0.poiCandidates }
        
        // 점수가 가장 높은 순으로 정렬
        let sortedCandidates = allCandidates.sorted { $0.score > $1.score }
        
        // 중복되지 않는 상위 2개의 장소 이름을 추출
        var landmarkNames: [String] = []
        for candidate in sortedCandidates {
            if !landmarkNames.contains(candidate.name) {
                landmarkNames.append(candidate.name)
            }
            if landmarkNames.count >= 2 {
                break
            }
        }
        
        if landmarkNames.isEmpty {
            // 랜드마크가 없으면 날짜 기반 제목으로 폴백
            guard let firstDate = days.first?.date, let lastDate = days.last?.date else {
                return "A Memorable Trip"
            }
            return firstDate == lastDate ? "Trip of \(firstDate)" : "Trip from \(firstDate)"
        } else if landmarkNames.count == 1 {
            return landmarkNames[0]
        } else {
            return "\(landmarkNames[0]) & \(landmarkNames[1])"
        }
    }

    // MARK: - Helper Functions
    
    private func generateAlbumTitle(from dates: [String]) -> String {
        guard let firstDateStr = dates.first, let lastDateStr = dates.last else { return "A Trip Album" }
        if firstDateStr == lastDateStr {
            return "Trip of \(firstDateStr)"
        }
        return "Trip: \(firstDateStr) - \(lastDateStr)"
    }
    
    private func getHighQualityImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.version = .original
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
