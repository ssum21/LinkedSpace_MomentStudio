//
//  MomentsView.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Displays a chronological feed of all moments from all trips. It allows
//           users to trigger on-demand POI ranking for any moment and view the results.
//

import SwiftUI

struct MomentsView: View {
    // MARK: - STATE MANAGEMENT
    
    /// The ViewModel for this view. @StateObject ensures it's created once and
    /// its lifecycle is tied to this view, as this is its primary screen.
    @StateObject private var viewModel = MomentsViewModel()

    // MARK: - BODY
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Set a consistent dark background.
                Color.black.ignoresSafeArea()
                
                // Conditionally display the content based on the ViewModel's state.
                if viewModel.allMoments.isEmpty {
                    emptyStateView
                } else {
                    momentsFeedList
                }
                
                // A loading overlay that appears when the POI ranking is in progress.
                if viewModel.isRanking {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView("Ranking Places...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("All Moments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // A refresh button to reload all moments from the cache.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadAllMomentsFromCache()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark)
            .onAppear {
                // When the tab appears, always try to refresh the moments list
                // to catch any changes made in the Trips tab.
                viewModel.loadAllMomentsFromCache()
            }
            // The sheet for the POI chooser, controlled by the ViewModel's state.
            .sheet(isPresented: $viewModel.showPOIChooser) {
                if let momentBinding = viewModel.momentToEdit {
                    POIChooserMapView(moment: momentBinding)
                        .onDisappear {
                            // When the sheet is dismissed, trigger the save logic.
                            viewModel.saveMomentsToCache()
                        }
                }
            }
            // An alert for displaying any ranking errors.
            .alert(item: $viewModel.rankingError) { message in
                Alert(title: Text("Analysis Error"), message: Text(message), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - SUBVIEWS
    
    /// The view displayed when no moments have been generated yet.
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.square.filled.on.square")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            Text("No Moments Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(viewModel.statusMessage)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    /// The scrollable list that displays the feed of all moment cards.
    private var momentsFeedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Iterate over the indices of the array for a more stable ForEach.
                ForEach(viewModel.allMoments.indices, id: \.self) { index in
                    // Create a binding to the element at the specific index.
                    let momentBinding = $viewModel.allMoments[index]
                    
                    MomentCardView(
                        moment: momentBinding,
                        onEdit: {
                            // Tell the ViewModel to start the ranking process for this specific moment.
                            Task {
                                await viewModel.rankPOIs(for: momentBinding)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - PREVIEW
struct MomentsView_Previews: PreviewProvider {
    static var previews: some View {
        MomentsView()
            .preferredColorScheme(.dark)
    }
}
