//
//  DayDetailViewModel.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Manages the state and business logic for the DayDetailView. It handles
//           on-demand POI ranking when a user wants to edit a moment's location,
//           manages loading/error states, and prepares map data for the view.
//
import SwiftUI
import MapKit
import Photos

struct MomentAnnotation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}


@MainActor
class DayDetailViewModel: ObservableObject {
    @Published var day: Day
    @Published var annotations: [MomentAnnotation] = []
    @Published var cameraPosition: MapCameraPosition
    @Published var isRanking: Bool = false
    @Published var rankingError: String?
    @Published var momentToEdit: Binding<Moment>?
    @Published var showPOIChooser: Bool = false
    
    private let rankingEngine: POIRankingEngine
    private let mobileCLIPClassifier: ZSImageClassification
    private var dayBinding: Binding<Day>

    init(dayBinding: Binding<Day>) {
        self.dayBinding = dayBinding
        self._day = Published(initialValue: dayBinding.wrappedValue)
        
        let classifier = ZSImageClassification(model: defaultModel.factory())
        self.mobileCLIPClassifier = classifier
        self.rankingEngine = POIRankingEngine(classifier: classifier)
        
        // --- 초기 지도 설정 ---
        let initialDay = dayBinding.wrappedValue
        let momentAnnotations = initialDay.moments.compactMap { moment -> MomentAnnotation? in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [moment.representativeAssetId], options: nil)
            guard let asset = fetchResult.firstObject, let location = asset.location else { return nil }
            return MomentAnnotation(name: moment.name, coordinate: location.coordinate)
        }
        self.annotations = momentAnnotations
        if let firstCoordinate = momentAnnotations.first?.coordinate {
            self._cameraPosition = Published(initialValue: .region(MKCoordinateRegion(center: firstCoordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)))
        } else {
            self._cameraPosition = Published(initialValue: .automatic)
        }
    }
    
    // ▼▼▼ 이 함수가 "실시간 재분석"의 핵심입니다. ▼▼▼
    func rankPOIs(for momentBinding: Binding<Moment>) async {
        self.isRanking = true
        self.momentToEdit = momentBinding
        let moment = momentBinding.wrappedValue
        
        // 1. 분석에 필요한 사진과 좌표를 가져옵니다.
        guard let imagePixelBuffer = await getPixelBuffer(for: moment.representativeAssetId),
              let photoCoordinate = getCoordinate(for: moment.representativeAssetId)
        else {
            self.rankingError = "Could not prepare the photo for analysis."
            self.isRanking = false
            return
        }
        
        // 2. 주변 장소를 실시간으로 다시 가져옵니다.
        let placesService = GooglePlacesAPIService()
        let placesToRank = (try? await placesService.fetchAndCategorizePlaces(for: photoCoordinate).map { $0.place }) ?? []
        
        guard !placesToRank.isEmpty else {
            self.rankingError = "No nearby places found to rank."
            self.isRanking = false
            return
        }
        
        // 3. POIRankingEngine을 실시간으로 다시 실행합니다.
        let ranked = await rankingEngine.rankPlaces(
            places: placesToRank,
            imagePixelBuffer: imagePixelBuffer,
            photoLocation: photoCoordinate
        )
        
        guard !ranked.isEmpty else {
            self.rankingError = "Could not find any suitable candidates."
            self.isRanking = false
            return
        }
        
        // 4. 분석된 새로운 후보군을 생성합니다.
        let newCandidates = ranked.map {
            POICandidate(id: $0.place.placeId, name: $0.place.name, score: $0.finalScore, latitude: $0.place.location.lat, longitude: $0.place.location.lng)
        }
        
        // 5. 원본 moment 데이터의 poiCandidates를 새로운 결과로 덮어씁니다.
        momentBinding.wrappedValue.poiCandidates = newCandidates
        
        // 6. 모든 데이터가 준비된 후, 지도 뷰를 띄우라는 신호를 보냅니다.
        self.isRanking = false
        self.showPOIChooser = true
    }

    
    // MARK: - HELPER FUNCTIONS
    
    private func getPixelBuffer(for assetId: String) async -> CVPixelBuffer? {
        guard let image = await getHighQualityImage(for: assetId) else { return nil }
        return image.toCVPixelBuffer()
    }
    
    private func getHighQualityImage(for assetId: String) async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func getCoordinate(for assetId: String) -> CLLocationCoordinate2D? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        return fetchResult.firstObject?.location?.coordinate
    }
}
