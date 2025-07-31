//
//  TripsView.swift
//  MomentStudio
//
//  Created by SSUM on 7/29/25.
//
//  PURPOSE: This view is the main screen for the "Trips" tab. It displays a list of
//           automatically generated trip albums, handles loading and empty states,
//           and initiates the navigation flow into a trip's details.
//

import SwiftUI

struct TripsView: View {
    // MARK: - STATE MANAGEMENT
    
    /// The ViewModel for this view, passed in from a parent view (MainTabView).
    /// @ObservedObject is used because the parent view owns this ViewModel.
    @ObservedObject var viewModel: TripsViewModel

    // MARK: - BODY
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Set a consistent dark background for the entire view.
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Conditionally display content based on the ViewModel's state.
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.trips.isEmpty {
                    emptyStateView
                } else {
                    tripsListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ToolbarItem for the centered title and date navigation.
                ToolbarItem(placement: .principal) {
                    dateNavigationBar
                }
                
                // ToolbarItem for the top-right refresh/regenerate button.
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - SUBVIEWS
    
    /// The view displayed while the ViewModel is processing photos.
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: viewModel.progress) {
                // The label is not shown by default in this style, but is good for accessibility.
            } currentValueLabel: {
                // Shows the percentage, e.g., "55%"
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
            }
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(1.5)
            
            Text(viewModel.statusMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    /// The view displayed when no trips have been generated yet.
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Trips Found")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(viewModel.statusMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // A prominent button for the user to initiate the analysis.
            Button(action: {
                Task {
                    await viewModel.generateNewTrips()
                }
            }) {
                Label("Find My Trips Now", systemImage: "sparkles")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
    }
    
    /// The view that displays the list of generated trip albums.
    private var tripsListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Iterate over the ViewModel's trips array with a binding ($)
                // to allow child views to modify the data.
                ForEach($viewModel.trips) { $trip in
                    NavigationLink(destination: TripDetailView(trip: $trip)) {
                         TripCardView(trip: trip)
                    }
                }
            }
            .padding()
        }
    }
    
    /// The custom navigation bar UI for date selection.
    private var dateNavigationBar: some View {
        HStack {
            Button(action: { /* TODO: Go to previous month */ }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text("Recent Trips") // Changed title for clarity
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Button(action: { /* TODO: Go to next month */ }) {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundColor(.white)
    }
    
    /// The top-right button for regenerating albums.
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.generateNewTrips()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
        .foregroundColor(.white)
    }
}

// MARK: - PREVIEW
struct TripsView_Previews: PreviewProvider {
    
    static func createMockViewModel(isEmpty: Bool) -> TripsViewModel {
        let mockViewModel = TripsViewModel()
        if !isEmpty {
            mockViewModel.trips = [TripAlbum.mock, TripAlbum.mock]
        }
        return mockViewModel
    }
    
    static var previews: some View {
        // Previewing MainTabView is a good way to test the whole flow.
        MainTabView()
            .preferredColorScheme(.dark)
    }
}
