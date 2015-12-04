//
//  BBAudioModel.h
//  Bubble Beat
//
//  author: scott
//  [sonic apps union]
//
//  description: This is a static/singleton class that deals with
//  all the audio processing in the application

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "fft.h"
#import "bark.h"
#import "peak_picker.h"

@interface BBAudioModel : NSObject
{
    AudioUnit bbUnit;                   // This is the actual audio unit instance variable
    
    int       blockSize;
    int       sampleRate;
    int       hopSize;
    int       windowSize;
    
    float*    monoAnalysisBuffer;       // mono signal that we do analysis on
    float*    musicLibraryBuffer;       // An intermediate buffer for audio content from music library
    int*      musicLibraryReadPosition;
    int       musicLibraryBufferSize;
    double    musicLibraryDuration;     // this is the duration of the audio file so we can figure out when it's done
    int       musicLibraryCurrentPosition;
    
    BOOL      inputType;                // YES = Microphone, NO = Music
    BOOL      mic;
    BOOL      music;
    
    FFT*       fft;
    FFT_FRAME* fftFrame;
    
    BARK*     bark;
    PEAK_PICKER* peak_picker;
    
    Float32* left;
    Float32* right;
    
    NSTimer* updateTimer;
    
//    NSOperationQueue* queue;            // onset detection queue
    
    float upperThresh;
    int renderTime;
    
    BOOL    gotOnset;
    float   salience;
    
}

+ (BBAudioModel *)sharedAudioModel;
- (void)setupAudioUnit;
- (void)startAudioUnit;

- (void)setupAudioSession;
- (void)startAudioSession;

- (void)setMicrophoneInput;
- (void)setMusicInput;

- (void)setupMediaBuffers:(float *)readBuffer position:(int *)readPosition size:(int)size;
- (void)onsetDetected:(float)salience;
- (void)clearMusicLibraryBuffer;

@property int blockSize;
@property int sampleRate;
@property float* musicLibraryBuffer;
@property BOOL canReadMusicFile;
@property BOOL inputType;
@property double musicLibraryDuration;

@property BOOL gotOnset;
@property float salience;

@end

// C Functions
static float outerEarFilter(float input);
static float middleEarFilter(float input);
