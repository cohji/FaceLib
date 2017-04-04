//
//  ViewController.swift
//  FaceLib
//
//  Created by Koji Suzuki on 2017/04/04.
//  Copyright © 2017 Koji Suzuki. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    var mySession: AVCaptureSession!
    var myCamera: AVCaptureDevice!
    var myVideoInput: AVCaptureDeviceInput!
    var myVideoOutput: AVCaptureVideoDataOutput!
    var myVideoLayer: AVSampleBufferDisplayLayer!
    var myMetaOutput: AVCaptureMetadataOutput!
    var currentMetadata: [AnyObject] = []
    
    let faceLib = FaceLib()
    
    
    @IBOutlet weak var myImageView: UIImageView!
    
    @IBAction func onPartsSw(_ sender: UISwitch) {
        faceLib.dispPartsFlag(sender.isOn)
    }
    
    @IBAction func onAnglesSw(_ sender: UISwitch) {
        faceLib.dispAnglesFlag(sender.isOn)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        prepareVideo()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func prepareVideo() {
        
        // connect
        mySession = AVCaptureSession()
        mySession.sessionPreset = AVCaptureSessionPresetHigh
        
        // access point
        myCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let input = try!AVCaptureDeviceInput(device: myCamera)
        mySession.addInput(input)
        
        // video settings
        myVideoOutput = AVCaptureVideoDataOutput()
        myVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable:Int(kCVPixelFormatType_32BGRA)]
        myVideoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "samplequeue"))
        myVideoOutput.alwaysDiscardsLateVideoFrames = true
        mySession.addOutput(myVideoOutput)
        
        // metadata settings
        myMetaOutput = AVCaptureMetadataOutput()
        myMetaOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "facequeue"))
        mySession.addOutput(myMetaOutput)
        myMetaOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
        
        // generate a layer to display images
        myVideoLayer = AVSampleBufferDisplayLayer()
        myVideoLayer.frame = self.view.bounds
        myVideoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        // add view to layer
        self.myImageView.layer.addSublayer(myVideoLayer)
        
        // camera orientation
        for connection in self.myVideoOutput.connections {
            if let conn = connection as? AVCaptureConnection {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = AVCaptureVideoOrientation.portrait
                }
            }
        }
        
        mySession.startRunning()
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        
        DispatchQueue.main.sync{
            if !self.currentMetadata.isEmpty {
                
                // get bounds from metadata
                let bounds = self.currentMetadata
                    .flatMap { $0 as? AVMetadataFaceObject }
                    .map { (faceObject) -> NSValue in
                        let convertedObject = captureOutput.transformedMetadataObject(for: faceObject, connection: connection)
                        return NSValue(cgRect: convertedObject!.bounds)
                }
                
                // get face features from sample buffer
                let faces = faceLib.getFeatures(sampleBuffer, bounds: bounds)
                printFeatures(faces: faces!)
            }
        }
        
        self.myVideoLayer.enqueue(sampleBuffer)
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        currentMetadata = metadataObjects as [AnyObject]
    }
    
    func printFeatures(faces: [[[NSValue]]]) {
        for face in faces as [[[NSValue]]] {
            var count = 1
            for features in face as [[NSValue]] {
                if(count == 1) {
                    NSLog("Nose tip: %@", features[30])
                    NSLog("Chin: %@", features[8])
                    NSLog("Left eye left corner: %@", features[36])
                    NSLog("Right eye right corner: %@", features[45])
                    NSLog("Left Mouth corner: %@", features[48])
                    NSLog("Right mouth corner: %@", features[54])
                    count = 2
                } else if(count == 2) {
                    NSLog("pitch: %@", features[0])
                    NSLog("yaw: %@", features[1])
                    NSLog("roll: %@", features[2])
                }
            }
        }
    }
}

