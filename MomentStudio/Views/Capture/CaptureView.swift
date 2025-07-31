//
//  CaptureView.swift
//  MomentStudio
//
//  Created by SSUM on 7/29/25.
//
//  PURPOSE: Provides the camera interface for capturing new photos. It uses
//           CameraController to manage the camera feed and overlays UI controls.
//

import SwiftUI
import AVFoundation

struct CaptureView: View {
    // MARK: - STATE
    
    /// The controller that manages the camera session.
    /// @StateObject ensures the controller's lifecycle is tied to the view.
    @State private var cameraController = CameraController()

    // MARK: - BODY
    
    var body: some View {
        ZStack {
            // The camera preview layer. This will be black on the simulator
            // but will show the camera feed on a real device.
            CameraPreview(session: cameraController.captureSession)
                .ignoresSafeArea()
            
            // UI controls overlaid on top of the camera view.
            CaptureViewOverlay(cameraController: cameraController)
        }
        .onAppear {
            // When the view appears, start the camera session.
            cameraController.start()
        }
        .onDisappear {
            // When the view disappears, stop the session to save resources.
            cameraController.stop()
        }
        // Set the background to black to handle safe areas gracefully.
        .background(Color.black)
    }
}

// MARK: - Capture UI Overlay

/// A view that contains only the UI controls for the capture screen.
/// This can be used in previews without needing a live camera feed.
struct CaptureViewOverlay: View {
    /// The camera controller, passed from the parent view.
    let cameraController: CameraController

    /// A state variable to trigger the screen flash animation.
    @State private var showFlashAnimation = false

    var body: some View {
        VStack {
            // Top controls (e.g., flash, settings)
            HStack {
                Button(action: { /* TODO: Implement flash toggle logic */ }) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.title2)
                }
                Spacer()
                Text("Vibe On")
                    .fontWeight(.bold)
                Image(systemName: "waveform")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(Color.black.opacity(0.3))
            
            Spacer()
            
            // Bottom controls (shutter, gallery, flip camera)
            HStack(alignment: .center, spacing: 50) {
                // Gallery thumbnail button
                Button(action: {
                    // This URL scheme attempts to open the Photos app.
                    if let url = URL(string:"photos-redirect://") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                }
                
                // Shutter button
                Button(action: {
                    // Call the capturePhoto function on the controller.
                    cameraController.capturePhoto()
                    
                    // Trigger the flash animation for user feedback.
                    triggerFlashAnimation()
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
                
                // Flip camera button
                Button(action: {
                    // Toggle the backCamera property to switch cameras.
                    cameraController.backCamera.toggle()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.largeTitle)
                }
            }
            .foregroundColor(.white)
            .frame(height: 100)
            .padding(.bottom, 40)
        }
        .overlay(
            // A white view that quickly appears and disappears to simulate a camera flash.
            Color.white
                .opacity(showFlashAnimation ? 0.7 : 0)
                .ignoresSafeArea()
        )
    }
    
    /// A helper function to manage the flash animation.
    private func triggerFlashAnimation() {
        withAnimation(.easeInOut(duration: 0.1)) {
            showFlashAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showFlashAnimation = false
            }
        }
    }
}


// MARK: - CameraPreview UIViewRepresentable

/// A helper view to wrap the AVCaptureVideoPreviewLayer in a SwiftUI View.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        guard let validSession = session else { return view }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: validSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.layer.name = "CameraPreviewLayer"
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the preview layer and ensure its frame matches the view's bounds.
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0.name == "CameraPreviewLayer" }) as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            
            // If the session changes (e.g., on camera flip), update the layer's session.
            if previewLayer.session != session {
                previewLayer.session = session
            }
        } else if let validSession = session {
            // If the layer doesn't exist yet but the session is now valid, create it.
            let previewLayer = AVCaptureVideoPreviewLayer(session: validSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = uiView.bounds
            previewLayer.name = "CameraPreviewLayer"
            uiView.layer.insertSublayer(previewLayer, at: 0)
        }
    }
}


// MARK: - PREVIEW

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Simulate the camera view with a black background for the preview.
            Color.black.ignoresSafeArea()
            
            // Render only the UI overlay for a crash-free preview.
            // Pass a new instance of CameraController for the preview.
            CaptureViewOverlay(cameraController: CameraController())
        }
        .preferredColorScheme(.dark)
    }
}
