//
//  MainTabView.swift
//  MomentStudio
//
//  Created by SSUM on 7/29/25.
//
//  PURPOSE: The root view of the application. It manages tab selection via AppState
//           and provides the initial views for each tab.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case trips = "Trips"
    case moments = "Moments"
    case capture = "Capture"
}

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @StateObject private var tripsViewModel = TripsViewModel()
    
    @Namespace private var tabAnimationNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                switch appState.selectedTab {
                case .trips:
                    // TripsView now manages its own navigation stack.
                    TripsView(viewModel: tripsViewModel)
                case .moments:
                    // MomentsView is now an independent view.
                    MomentsView()
                case .capture:
                    CaptureView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
                .padding(.bottom, 20)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    private var customTabBar: some View {
        HStack(spacing: 10) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    selectedTab: $appState.selectedTab,
                    namespace: tabAnimationNamespace
                )
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 43)
        .background(Color.gray.opacity(0.5))
        .cornerRadius(24)
        .padding(.horizontal, 60)
    }
}


// MARK: - TabBarButton (Helper View)
struct TabBarButton: View {
    let tab: AppTab
    
    // This binding now connects directly to the AppState's selectedTab.
    @Binding var selectedTab: AppTab
    
    let namespace: Namespace.ID
    
    var body: some View {
        Button(action: {
            // Animate the change of the global selected tab.
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }) {
            Text(tab.rawValue)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        if selectedTab == tab {
                            Color.white.opacity(0.2)
                                .cornerRadius(24)
                                .matchedGeometryEffect(id: "selectedTabBackground", in: namespace)
                        }
                    }
                )
        }
    }
}


// MARK: - PREVIEW
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
