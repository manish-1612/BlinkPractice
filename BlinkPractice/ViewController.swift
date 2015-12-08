//
//  ViewController.swift
//  BlinkPractice
//
//  Created by Manish Kumar on 04/12/15.
//  Copyright © 2015 Innofied Solutions Pvt. Ltd. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioPlayerDelegate {

    
    var audioPlayer = BBMediaPlayer()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        BBAudioModel.sharedAudioModel().setupAudioSession()
        BBAudioModel.sharedAudioModel().setupAudioUnit()
        BBAudioModel.sharedAudioModel().startAudioUnit()
        BBAudioModel.sharedAudioModel().startAudioSession()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "onsetDetected:", name: "onsetDetected", object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "mediaPickerFinished:", name: "mediaPickerFinished", object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "songFinished:", name: "songFinished", object: nil)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func playMusic(sender: AnyObject) {
        
        let path = NSBundle.mainBundle().pathForResource("song", ofType:"mp3")
        let fileURL = NSURL(fileURLWithPath: path!)
        
        
        audioPlayer = BBMediaPlayer()
        BBAudioModel.sharedAudioModel().setMusicInput()
        BBAudioModel.sharedAudioModel().canReadMusicFile = true
        audioPlayer.parentViewController = self
        audioPlayer.showMediaPicker()
    }
    
    func onsetDetected(notification : NSNotification){
       
        let salience : CGFloat = (notification.userInfo!["salience"] as? CGFloat)!
        
        print("salience : \(salience)")
        
        blinkTorchWithSalience(salience)
    }
    
    
    func mediaPickerFinished(notification : NSNotification){
        print("picking finished")
        audioPlayer.play()
    }
    
    
    func blinkTorchWithSalience(salience: CGFloat) {
        
        let avDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        // check if the device has torch
        if avDevice.hasTorch {
            // lock your device for configuration
            
            do {
                try avDevice.lockForConfiguration()
            }
            catch {
                print("something went wrong")
            }
            
            
            // check if your torchMode is on or off. If on turns it off otherwise turns it on
            if avDevice.torchMode == AVCaptureTorchMode.On {
                print("making it off")
                avDevice.torchMode = AVCaptureTorchMode.Off
            } else {
                // sets the torch intensity to 100%
                
                print("making it on")

                do {
                    
                    if salience > 1.5 && salience <= 1.8 {
                        try avDevice.setTorchModeOnWithLevel(1.0)
                    }else if salience > 1.8 && salience <= 2.3 {
                        try avDevice.setTorchModeOnWithLevel(1.0)
                    }else{
                        try avDevice.setTorchModeOnWithLevel(1.0)
                    }
                    
                } catch{
                    print("error while setting torch mode to on")
                }
            }
            // unlock your device
            avDevice.unlockForConfiguration()
        }
    }

    
    
    func closeTheTorch(){
        
        let avDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        // check if the device has torch
        if avDevice.hasTorch {
            // lock your device for configuration
            
            do {
                try avDevice.lockForConfiguration()
            }
            catch {
                print("something went wrong")
            }
            
            // check if your torchMode is on or off. If on turns it off otherwise turns it on
            if avDevice.torchMode == AVCaptureTorchMode.On {
                avDevice.torchMode = AVCaptureTorchMode.Off
            }
            // unlock your device
            avDevice.unlockForConfiguration()
        }
    }
    
    
    func songFinished(notification : NSNotification){
        
        closeTheTorch()
    }
}

