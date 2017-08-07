//
//  ViewController.swift
//  VideoIQ
//
//  Created by Sergelenbaatar Tsogtbaatar on 8/6/17.
//  Copyright © 2017 Sergstaeb. All rights reserved.
//

import AVKit
import UIKit

enum SetupError: Error {
    case noVideoDevice, videoInputFailed, videoOutputFailed
}

class ViewController: UIViewController, UINavigationControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let model = SqueezeNet()
    let context = CIContext()
    let session = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    var capturePreview = CapturePreviewView()
    var assetWriter: AVAssetWriter!
    var writerInput: AVAssetWriterInput!
    var recordingActive = false
    var readyToAnalyze = true
    var startTime: CMTime!
    var movieURL: URL!
    var predictions = [(time: CMTime, prediction: String)]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create Auto Layout constraints pinning it to all four edges of our view
        capturePreview.translatesAutoresizingMaskIntoConstraints =
        false
        view.addSubview(capturePreview)
        capturePreview.topAnchor.constraint(equalTo:
            view.topAnchor).isActive = true
        capturePreview.bottomAnchor.constraint(equalTo:
            view.bottomAnchor).isActive = true
        capturePreview.leadingAnchor.constraint(equalTo:
            view.leadingAnchor).isActive = true
        capturePreview.trailingAnchor.constraint(equalTo:
            view.trailingAnchor).isActive = true
        // tell it to attach to our existing session
        (capturePreview.layer as!
            AVCaptureVideoPreviewLayer).session = session
        do {
            // attempt to configure the session
            try configureSession()
            // if it worked, add a "Record" button
            navigationItem.rightBarButtonItem =
                UIBarButtonItem(title: "Record", style: .plain, target: self,
                                action: #selector(startRecording))
        } catch {
            // if it failed for any reason, print a log message
            print("Session configuration failed!")
        }
        
    }
    
    @objc func startRecording() {
        recordingActive = true
        session.startRunning()
    }
    
    func configureVideoDeviceInput() throws {
        // find the default video device or throw an error
        guard let videoCaptureDevice = AVCaptureDevice.default(for:
            AVMediaType.video) else {
                throw SetupError.noVideoDevice
        }
        
        let videoDeviceInput = try AVCaptureDeviceInput(device:
            videoCaptureDevice)
        // add it to our recording session or throw an error
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
        } else {
            throw SetupError.videoInputFailed
        }
    }
    
    func configureSession() throws {
        session.beginConfiguration()
        try configureVideoDeviceInput()
        session.commitConfiguration()
    }
    
    func configureVideoDeviceOutput() throws {
        if session.canAddOutput(videoOutput) {
            // configure this view controller to receive video data packets
            videoOutput.setSampleBufferDelegate(self, queue:
                DispatchQueue.main)
            session.addOutput(videoOutput)
            // force portrait recording
            for connection in videoOutput.connections {
                for port in connection.inputPorts {
                    if port.mediaType == .video {
                        connection.videoOrientation = .portrait
                    } }
            }
        } else {
            throw SetupError.videoOutputFailed
        }
    }
    
}
