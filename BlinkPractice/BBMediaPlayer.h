//
//  BBMediaPlayer.h
//  Bubble Beat
//
//  Created by Scott McCoid on 5/13/13.
//
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

#define DEFAULT_BUFFERING_AMOUNT 4              // four seconds of 'buffering'
#define SAMPLE_RATE 44100.0

@interface BBMediaPlayer : NSObject <MPMediaPickerControllerDelegate>
{
    MPMediaPickerController* mediaPicker;
    NSOperationQueue* queue;
    NSDictionary* audioSetting;
    NSMutableArray* mediaItemQueue;             // queued media items
    
    int mediaWritePosition;
    NSURL* currentSongURL;                      // location of current song
    
}

@property (nonatomic, weak) UIViewController* parentViewController;
@property (readonly) BOOL playing;              // whether player is currently playing audio

@property float* mediaBuffer;                   // audio buffer for the iTunes song
@property int mediaReadPosition;                // able to get/set the sample read position
@property int mediaLength;                      // length of the song in samples
@property double mediaFileDuration;             // duration of audio file selected
@property int bufferingAmount;                  // length/size of buffering array in samples (stereo interleaved file)

@property (readonly) BOOL newFileSelected;      // whether a new file was selected or not (aka, need to start from beginning)
@property (readonly) BOOL fileFinished;         // if we've reached the end of the file or not
@property (readonly) BOOL restartSong;
@property (readonly) BOOL initialRead;
@property (readonly) BOOL loadingInBackground;

@property (strong, nonatomic) NSString* title;  // title of current track
@property (strong, nonatomic) NSString* artist; // artist of current track

- (void)play;                                   // play current media item
- (void)pause;                                  // pause current media item
- (void)reset;
- (void)showMediaPicker;                        // displays the media picker

@end
