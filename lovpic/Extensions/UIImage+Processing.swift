//
//  UIImage+Processing.swift
//  lovpic
//
//  Created by Codex on 2025-01-15.
//

import UIKit

extension UIImage {
    /// Returns the image rendered in `.up` orientation so Vision/CoreImage can consume it safely.
    func normalized() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
