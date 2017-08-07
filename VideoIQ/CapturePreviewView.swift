//
//  CapturePreviewView.swift
//  VideoIQ
//
//  Created by Sergelenbaatar Tsogtbaatar on 8/6/17.
//  Copyright © 2017 Sergstaeb. All rights reserved.
//

import UIKit
import AVFoundation

class CapturePreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

}
