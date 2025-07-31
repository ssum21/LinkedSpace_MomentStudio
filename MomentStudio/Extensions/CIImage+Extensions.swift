//
//  CIImage+Extensions.swift
//  MomentStudio
//
//  Created by SSUM on 7/30/25.
//
//  PURPOSE: Extends CIImage with helpful methods for cropping and resizing,
//           which are necessary for preparing images for the Core ML model.
//

import CoreImage
import UIKit // For accessing UIGraphicsImageRenderer

extension CIImage {
    
    /// Crops the image to a square, taking the largest possible square from the center.
    /// - Returns: A new, square CIImage.
    func cropToSquare() -> CIImage {
        let side = min(extent.width, extent.height)
        let xOffset = (extent.width - side) / 2
        let yOffset = (extent.height - side) / 2
        return self.cropped(to: CGRect(x: xOffset, y: yOffset, width: side, height: side))
    }
    
    /// Resizes the image to a specific target size.
    /// - Parameter size: The target CGSize to resize to.
    /// - Returns: A new, resized CIImage.
    func resize(size: CGSize) -> CIImage {
        // Calculate the scale needed to resize the image.
        let scale = size.width / self.extent.width
        
        // Use the Lanczos Scale Transform filter for high-quality resizing.
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(self, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        
        // The aspect ratio is maintained by the scale calculation,
        // so we can set this to 1.0.
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        return filter.outputImage!
    }
}
