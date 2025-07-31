//
//  AppState.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Manages the global state of the application, now simplified
//           to only handle the active tab selection.
//

import SwiftUI

@MainActor
class AppState: ObservableObject {
    /// The currently selected tab in the MainTabView.
    @Published var selectedTab: AppTab = .trips
}
