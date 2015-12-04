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
        
//        [[NSNotificationCenter defaultCenter]
//            addObserver:self
//            selector:@selector(onsetDetected:)
//        name:@"onsetDetected"
//        object:nil ];
        
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "onsetDetected:", name: "onsetDetected", object: nil)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func blinkTorch(sender: AnyObject) {
        
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
            } else {
                // sets the torch intensity to 100%
                do {
                    try avDevice.setTorchModeOnWithLevel(1.0)
                } catch{
                    print("error while setting torch mode to on")
                }
            }
            // unlock your device
            avDevice.unlockForConfiguration()
        }
    }

    @IBAction func playMusic(sender: AnyObject) {
        
        let path = NSBundle.mainBundle().pathForResource("song", ofType:"mp3")
        let fileURL = NSURL(fileURLWithPath: path!)
        
        do {
            
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: AVAudioSessionCategoryOptions.DuckOthers)
            
            do {
                try  AVAudioSession.sharedInstance().setActive(true, withOptions: AVAudioSessionSetActiveOptions.init(rawValue:1))
                
                audioPlayer = BBMediaPlayer()
                BBAudioModel.sharedAudioModel().setMusicInput()
                
                

            }catch let error as NSError {
                print("error in making audio session active")
                print("error : \(error.localizedDescription)")
            }
            
        }catch let error as NSError{
            print("error in creating audio session")
            print("error : \(error.localizedDescription)")
        }
    }
    
    func onsetDetected(notification : NSNotification){
       
        let salience : CGFloat = (notification.userInfo!["salience"] as? CGFloat)!
        
        print("salience : \(salience)")
        
    }

    
}

