//
//  CameraController.swift
//  MomentStudio
//
//  Created by SSUM on 7/28/25 (Original by Apple Inc.).
//
//  PURPOSE: Manages the camera session, handling device discovery, permissions,
//           photo capture, and saving to the photo library with location data.
//

import AVFoundation
import CoreImage
import UIKit
import Photos      // For saving to the photo library
import CoreLocation // For accessing GPS location data

@Observable
class CameraController: NSObject {

    // MARK: - PUBLIC PROPERTIES
    
    public var backCamera = true {
        didSet {
            if oldValue != backCamera {
                stop()
                start()
            }
        }
    }
    
    public var captureSession: AVCaptureSession?
    
    // MARK: - PRIVATE PROPERTIES

    private var photoOutput: AVCapturePhotoOutput?
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "com.momentstudio.sessionQueue")
    
    // For location data
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    // MARK: - INITIALIZATION
    
    override init() {
        super.init()
        // Start location services when the controller is created.
        setupLocationServices()
    }
    
    // MARK: - PUBLIC METHODS
    
    public func stop() {
        sessionQueue.async { [self] in
            guard let session = captureSession, session.isRunning else { return }
            session.stopRunning()
            self.captureSession = nil
            print("Camera session stopped.")
        }
    }

    public func start() {
        sessionQueue.async { [self] in
            guard self.captureSession == nil else {
                print("Camera session is already active.")
                return
            }
            
            checkPermission()
            
            guard permissionGranted else {
                print("Camera permission not granted. Aborting start.")
                return
            }
            
            print("Starting camera session setup...")
            let newSession = AVCaptureSession()
            self.captureSession = newSession
            
            self.setupCaptureSession(on: newSession, position: backCamera ? .back : .front)
            
            if self.captureSession != nil {
                newSession.startRunning()
                print("Camera session started.")
            }
        }
    }
    
    /// Captures a photo and triggers the delegate method to save it.
    public func capturePhoto() {
        guard let photoOutput = self.photoOutput else {
            print("ERROR: Photo output is not configured.")
            return
        }
        
        // Settings for the photo capture.
        let photoSettings = AVCapturePhotoSettings()
        
        // Perform capture on the session queue.
        sessionQueue.async {
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - PRIVATE SETUP METHODS

    private func checkPermission() {
        // ... (이전과 동일, 수정 없음)
    }
    
    /// Configures the AVCaptureSession for high-quality photo capture.
    private func setupCaptureSession(on session: AVCaptureSession, position: AVCaptureDevice.Position) {
        // Begin configuration.
        session.beginConfiguration()
        
        // Set preset for high-quality photos.
        session.sessionPreset = .photo

        // 1. Find a suitable video device.
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], // Simplify for broader compatibility
            mediaType: .video,
            position: position)

        guard let videoDevice = deviceDiscoverySession.devices.first else {
            print("ERROR: No suitable video device found.")
            self.captureSession = nil
            session.commitConfiguration()
            return
        }

        // 2. Create a device input.
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                print("ERROR: Unable to add video input.")
                self.captureSession = nil
                session.commitConfiguration()
                return
            }
        } catch {
            print("ERROR: Could not create video device input: \(error)")
            self.captureSession = nil
            session.commitConfiguration()
            return
        }

        // 3. Create and configure a photo output.
        // We are no longer using the video data output for live frames.
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput // Store the output for later use.
        } else {
            print("ERROR: Unable to add photo output.")
            self.captureSession = nil
            session.commitConfiguration()
            return
        }
        
        // Commit all configuration changes.
        session.commitConfiguration()
    }
    
    /// Sets up the location manager to get GPS data for photos.
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
}

// MARK: - Photo Capture Delegate
extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error: Could not get image data from captured photo.")
            return
        }
        
        // Request authorization to save to the photo library.
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                print("Photo library access denied.")
                return
            }
            
            // Perform the save operation.
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
                
                // Add location data to the photo if available.
                if let location = self.currentLocation {
                    creationRequest.location = location
                }
                
            }) { success, error in
                if success {
                    print("Photo saved successfully to library with location.")
                } else if let error = error {
                    print("Error saving photo: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Location Manager Delegate
extension CameraController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Store the most recent location.
        self.currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
}
