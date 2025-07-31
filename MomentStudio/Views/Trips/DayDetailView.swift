//
//  DayDetailView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: [Refactored] Displays a day's details and manages user interactions.
//           This version improves readability and separates concerns more clearly.
//

import SwiftUI
import MapKit

// MARK: - MAIN VIEW (Container)

struct DayDetailView: View {
    // MARK: - STATE MANAGEMENT
    
    @StateObject private var viewModel: DayDetailViewModel

    // MARK: - INITIALIZATION
    
    init(day: Binding<Day>) {
        self._viewModel = StateObject(wrappedValue: DayDetailViewModel(dayBinding: day))
    }

    // MARK: - BODY
    
    var body: some View {
        // The ZStack now acts as a true container, layering the content
        // and the state-driven overlays (loading indicator).
        ZStack {
            // The main content is fully encapsulated in its own view.
            DayDetailViewContent(
                day: $viewModel.day,
                annotations: viewModel.annotations,
                cameraPosition: $viewModel.cameraPosition,
                onEditMoment: { momentBinding in
                    Task {
                        await viewModel.rankPOIs(for: momentBinding)
                    }
                }
            )
            
            // The loading overlay is managed here, at the container level.
            if viewModel.isRanking {
                loadingOverlay
            }
        }
        .navigationTitle(viewModel.day.date)
        .navigationBarTitleDisplayMode(.inline)
        // The sheet and alert modifiers are also part of the container's responsibility.
        .sheet(isPresented: $viewModel.showPOIChooser) {
            if let momentBinding = viewModel.momentToEdit {
                POIChooserMapView(moment: momentBinding)
            }
        }
        .alert("Analysis Error", isPresented: .constant(viewModel.rankingError != nil), presenting: viewModel.rankingError) { error in
            // Default OK button is fine.
        } message: { message in
            Text(message)
        }
    }
    
    // MARK: - SUBVIEWS (for DayDetailView)
    
    /// A view builder for the loading overlay, making the body cleaner.
    @ViewBuilder
    private var loadingOverlay: some View {
        Color.black.opacity(0.5).ignoresSafeArea()
        ProgressView("Ranking Nearby Places...")
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}

// MARK: - HELPER CONTENT VIEW

/// This view is now solely responsible for laying out the visible content.
struct DayDetailViewContent: View {
    @Binding var day: Day
    let annotations: [MomentAnnotation]
    @Binding var cameraPosition: MapCameraPosition
    var onEditMoment: (Binding<Moment>) -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // The map takes up the background.
            Map(position: $cameraPosition) {
                ForEach(annotations) { annotation in
                    Marker(annotation.name, coordinate: annotation.coordinate)
                }
            }
            .ignoresSafeArea()
            
            // The scrollable list of moments is overlaid on top.
            momentList
        }
    }
    
    /// A private computed property for the scrollable moment list.
    private var momentList: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // Draggable handle
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.vertical, 8)
                
                // The list of moment cards.
                LazyVStack(spacing: 16) {
                    ForEach($day.moments) { $moment in
                        MomentCardView(
                            moment: $moment,
                            onEdit: {
                                onEditMoment($moment)
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.6)
        .background(.thinMaterial)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
}

// MARK: - HELPERS & PREVIEW

// View Extension for Custom Corner Radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// String Extension for Alert
extension String: Identifiable {
    public var id: String { self }
}

// Preview Provider
struct DayDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            // Create a @State var to provide a binding for the preview.
            @State var mockDay = TripAlbum.mock.days.first!
            DayDetailView(day: $mockDay)
        }
        .preferredColorScheme(.dark)
    }
}
