//
//  POIChooserMapView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: An interactive map view presented as a sheet for selecting a moment's
//           location from a list of ranked candidates. It visualizes candidates
//           as ranked pins on a map.
//

import SwiftUI
import MapKit

struct POIChooserMapView: View {
    // MARK: - PROPERTIES
    
    /// A binding to the moment being edited. Changes made here (like updating the name)
    /// will be reflected in the original data source.
    @Binding var moment: Moment
    
    /// The environment value to dismiss the sheet.
    @Environment(\.dismiss) private var dismiss
    
    /// State to track the currently selected candidate annotation on the map.
    /// The `Map` view will automatically update this when a user taps a tagged Marker.
    @State private var selectedCandidate: POICandidate?
    
    /// The camera position for the map, calculated during initialization.
    @State private var cameraPosition: MapCameraPosition
    
    /// A computed property to get the top 7 candidates for display.
    private var candidates: [POICandidate] {
        Array(moment.poiCandidates.prefix(7))
    }
    
    // MARK: - INITIALIZATION
    
    init(moment: Binding<Moment>) {
        self._moment = moment
        
        // Calculate the initial camera position to focus on the top candidate.
        if let firstCandidate = moment.wrappedValue.poiCandidates.first {
            let centerCoordinate = CLLocationCoordinate2D(
                latitude: firstCandidate.latitude,
                longitude: firstCandidate.longitude
            )
            // Initialize the @State cameraPosition property wrapper.
            self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: centerCoordinate,
                latitudinalMeters: 1000, // Zoom in to see the candidates clearly
                longitudinalMeters: 1000
            )))
        } else {
            // Provide a default position if no candidates exist.
            self._cameraPosition = State(initialValue: .automatic)
        }
    }
    
    // MARK: - BODY
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // The main map view. The 'selection' parameter links map taps to the @State variable.
                Map(position: $cameraPosition, selection: $selectedCandidate) {
                    // Iterate over the top 7 candidates with their index for ranking.
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                        let coordinate = CLLocationCoordinate2D(latitude: candidate.latitude, longitude: candidate.longitude)
                        
                        // Use a Marker with a numbered system image to show the rank.
                        Marker(candidate.name, systemImage: "\(index + 1).circle.fill", coordinate: coordinate)
                            .tint(markerColor(for: candidate.score))
                            .tag(candidate) // Tag the marker with the candidate data for selection.
                    }
                }
                .ignoresSafeArea()
                
                // A bottom panel that appears only when a candidate pin is selected.
                if let selected = selectedCandidate {
                    VStack(spacing: 12) {
                        Text(selected.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(String(format: "Recommendation Score: %.2f", selected.score))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            // Update the moment's name with the selected candidate's name.
                            moment.name = selected.name
                            // Dismiss the sheet.
                            dismiss()
                        }) {
                            Text("Select this Place")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(15)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Choose a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Animate the appearance and disappearance of the bottom panel.
            .animation(.spring(), value: selectedCandidate)
        }
    }
    
    // MARK: - HELPER FUNCTION
    
    /// Determines the marker color based on the POI candidate's score.
    private func markerColor(for score: Float) -> Color {
        if score > 0.9 {
            return .red // Highest score
        } else if score > 0.75 {
            return .orange
        } else if score > 0.6 {
            return .blue
        } else {
            return .gray // Lower scores
        }
    }
}

// MARK: - PREVIEW
struct POIChooserMapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock moment with candidates for the preview.
        @State var mockMoment = Moment.mockData.first!
        
        POIChooserMapView(moment: $mockMoment)
    }
}
