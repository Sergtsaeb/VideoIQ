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
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:
            "Stop", style: .plain, target: self, action:
            #selector(stopRecording))
    }
    
    @objc func stopRecording() {
        recordingActive = false
        assetWriter?.finishWriting {
            if (self.assetWriter?.status == .failed) {
                print("Failed to save.")
            } else {
                print("Succeeded saving.")
            }
        }
        print("Creating movie file was a success.")
        
        DispatchQueue.main.async {
            let results = ResultsViewController(style: .plain)
            results.movieURL = self.movieURL
            results.predictions = self.predictions
            self.navigationController?.pushViewController(results,
                                                          animated: true)
        }
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
        try configureVideoDeviceOutput()
        try configureMovieWriting()
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
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func configureMovieWriting() throws {
        movieURL =
            getDocumentsDirectory().appendingPathComponent("movie.mov")
        let fm = FileManager.default
        if fm.fileExists(atPath: movieURL.path) {
            try fm.removeItem(at: movieURL)
        }
        
        // tell our asset writer where to save
        assetWriter = try AVAssetWriter(url: movieURL, fileType: .mp4)
        
        // figure out the best settings for writing MP4 movies
        let settings =
            videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .
                mp4)
        // create a writer using those settings, and configure it for real-time video
        writerInput = AVAssetWriterInput(mediaType: .video,
                                         outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = true
        // add the video recorder to the main recorder, so we're ready to go
        if assetWriter.canAdd(writerInput) {
            assetWriter.add(writerInput)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput
        sampleBuffer: CMSampleBuffer, from connection:
        AVCaptureConnection) {
        guard recordingActive else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) == true else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        if assetWriter.status == .failed {
            // Uh oh!
            return
        }
        if writerInput.isReadyForMoreMediaData {
            writerInput.append(sampleBuffer)
        }
        
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if assetWriter.status == .unknown {
            // store this away so we can calculate time offsets later
            startTime = currentTime
            // start writing data to disk
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: currentTime)
            // we're done for now, so exit
            return
        }
        
        guard readyToAnalyze else { return }
        readyToAnalyze = false
        
        // push work to a background thread
        DispatchQueue.global().async {
            // set our target scale size
            let inputSize = CGSize(width: 227.0, height: 227.0)
            let image = CIImage(cvImageBuffer: pixelBuffer)
            // create a CVPixelBuffer at the smaller size
            guard let resizedPixelBuffer = image.pixelBuffer(at:
                inputSize, context: self.context) else { return }
            // pass it to Core ML to identify an object
            let prediction = try? self.model.prediction(image:
                resizedPixelBuffer)
            // use the identified object name or "Unknown"
            let predictionName = prediction?.classLabel ?? "Unknown"
            // print a log of what's been found for debug purposes
            print("\(self.predictions.count): \(predictionName)")
            // figure out how much time has passed in the video
            let timeDiff = currentTime - self.startTime
            // append the new object to our array of predictions
            self.predictions.append((timeDiff, predictionName))
            // mark our code as being ready to analyze another frame
            self.readyToAnalyze = true
        }
    }
    
    
}

extension CIImage {
    func pixelBuffer(at size: CGSize, context: CIContext) ->
        CVPixelBuffer? {
            let attributes = [kCVPixelBufferCGImageCompatibilityKey:
                kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey:
                kCFBooleanTrue] as CFDictionary
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                             Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB,
                                             attributes, &pixelBuffer)
            guard status == kCVReturnSuccess else { return nil }
            let scale = size.width / self.extent.size.width
            let resizedImage = self.transformed(by:
                CGAffineTransform(scaleX: scale, y: scale))
            let width = resizedImage.extent.width
            let height = resizedImage.extent.height
            let yOffset = (CGFloat(height) - size.height) / 2.0
            let rect = CGRect(x: (CGFloat(width) - size.width) / 2.0,
                              y: yOffset, width: size.width, height: size.height)
            let croppedImage = resizedImage.cropped(to: rect)
            let translatedImage = croppedImage.transformed(by:
                CGAffineTransform(translationX: 0, y: -yOffset))
            CVPixelBufferLockBaseAddress(pixelBuffer!,
                                         CVPixelBufferLockFlags(rawValue: 0))
            context.render(translatedImage, to: pixelBuffer!)
            CVPixelBufferUnlockBaseAddress(pixelBuffer!,
                                           CVPixelBufferLockFlags(rawValue: 0))
            return pixelBuffer
    }
}
