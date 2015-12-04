//
//  BBAudioModel.m
//  Bubble Beat
//
//  author: scott
//  [sonic apps union]
//
//  description: This is a static/singleton class that deals with
//  all the audio processing in the application. 

#import "BBAudioModel.h"
#define NUM_SECONDS 24           // This is 2 * number of seconds in buffer 8 = 4 seconds of stereo audio

@implementation BBAudioModel

@synthesize blockSize;
@synthesize sampleRate;
@synthesize musicLibraryBuffer;
@synthesize canReadMusicFile;
@synthesize inputType;
@synthesize musicLibraryDuration;
@synthesize gotOnset;
@synthesize salience;

#pragma mark - Audio Render Callback -

static OSStatus renderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    BBAudioModel* model = (__bridge BBAudioModel*)inRefCon;
    AudioUnitRender(model->bbUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    
    // Use this variable to remove audio glitch moving from mic to music
    BOOL audioInputSource = model->inputType;
    
    float numInputChannels;
    int musicPosition;

    if (audioInputSource == model->mic)
    {
        numInputChannels = 1;
        model->left = (Float32 *)ioData->mBuffers[0].mData;
        model->right = (Float32 *)ioData->mBuffers[1].mData;
    }
    else
    {
        numInputChannels = 2;
        if (model->canReadMusicFile == YES) // If we are allowed to read from these buffers
        {
            musicPosition = (*model->musicLibraryReadPosition);
            for (int sample = 0; sample < inNumberFrames; sample++)
            {
                model->left[sample] = model->musicLibraryBuffer[musicPosition];
                model->right[sample] = model->musicLibraryBuffer[musicPosition + 1];
                musicPosition = (musicPosition + 2) % model->musicLibraryBufferSize;
            }
            
            // update position through the songfile to determine where we're at
            model->musicLibraryCurrentPosition += inNumberFrames;
            if (model->musicLibraryCurrentPosition >= model->musicLibraryDuration)
            {
                model->canReadMusicFile = NO;
                model->musicLibraryCurrentPosition = 0;     // reset position
            }
            
            (*(model->musicLibraryReadPosition)) = musicPosition;
        }
        else    // we're not allowed to read from these buffers, spit out 0.0's
        {
            vDSP_vclr(model->left, 1, inNumberFrames);
            vDSP_vclr(model->right, 1, inNumberFrames);
        }
    }
    
    int sizeDiff = model->windowSize - inNumberFrames;
    // shift previous values into front
    for (int i = 0; i < sizeDiff; i++)
        model->monoAnalysisBuffer[i] = model->monoAnalysisBuffer[i + inNumberFrames];
    
    // input convert to mono and shift into analysis buffer
//    for (int i = 0; i < inNumberFrames; i++)
//    {
//        float mono = (model->left[i] + model->right[i]) / numInputChannels;               // I think one of these channels will just have 0.0s if it's set to mic input
//        mono = outerEarFilter(mono);
//        model->monoAnalysisBuffer[sizeDiff + i] = middleEarFilter(mono);
//        
////        model->monoAnalysisBuffer[sizeDiff + i] = (model->left[i] + model->right[i]) / numInputChannels;
//    }
    
    // sum channels
    vDSP_vadd(model->left, 1, model->right, 1, model->monoAnalysisBuffer + sizeDiff, 1, inNumberFrames);
    if (numInputChannels > 1)
    {
        vDSP_vsdiv(model->monoAnalysisBuffer + sizeDiff, 1, &numInputChannels, model->monoAnalysisBuffer + sizeDiff, 1, inNumberFrames);
    }
    
    // fft takes care of windowing for us
    fft(model->fftFrame, model->monoAnalysisBuffer);
    
    // get magnitude
    magnitude(&model->fftFrame->buffer, model->monoAnalysisBuffer, model->fft->sizeOverTwo);
    
    // multiply analysis buffer by the filterbank
    multiplyBarkFilterbank(model->bark, model->monoAnalysisBuffer);
    
    // Condense everything
    condenseAnalysis(model->bark, model->monoAnalysisBuffer);
    
    // Multiply by loudness curves
    multiplyLoudness(model->bark);
    
    // -- Spectral Flux peak picking -- //
    if (model->bark->prevBarkBins != NULL) {
        
        //get into our feature space
        accumulate_bin_differences(model->peak_picker, model->bark);
        
        //apply perceptual mask
        //applyMask(model->peak_picker);
        
        //consecutive onset filtering
        filterConsecutiveOnsets(model->peak_picker);
        
        //find peaks
        if(pickPeaks(model->peak_picker))
        {
//            [model onsetDetected:model->peak_picker->peak_value];
            model->gotOnset = YES;
            model->salience = model->peak_picker->peak_value;
        }
        
    }
    
    //updateQueue(model->peak_picker);
    iterateBarkBins(model->bark);
    
    // Dealing with output
    for (int channel = 0; channel < ioData->mNumberBuffers; channel++)
    {
        // Get reference to buffer for channel we're on
        Float32* output = (Float32 *)ioData->mBuffers[channel].mData;
        
        // Loop through the blocksize
        for (int frame = 0; frame < inNumberFrames; frame++)
        {
            if (audioInputSource == model->mic)    // If we're using the microphone set output to 0.0 so we don't feedback
                output[frame] = 0.0;
            else
            {
                // TODO: clean this up
                if (channel == 0)
                    output[frame] = model->left[frame];
                else if (channel == 1)
                    output[frame] = model->right[frame];
            }
        }
    }
    
    return noErr;
}

#pragma mark - Audio Session Property Listener -

void propertyListener(void *inClientData,
                  AudioSessionPropertyID inID,
                  UInt32                 inDataSize,
                  const void *           inData)
{
    //BBAudioModel* model = (__bridge BBAudioModel*)inClientData;
    if (inID == kAudioSessionProperty_AudioRouteChange)
    {
        BOOL check = CFDictionaryContainsKey(inData, kAudioSession_RouteChangeKey_Reason);
        if (check)
        {
            //CFStringRef reason = CFDictionaryGetValue(inData, kAudioSession_RouteChangeKey_Reason);
            //const char* str = CFStringGetCStringPtr(reason, kCFStringEncodingMacRoman);
            //NSLog(@"Route Changed Reason: %@", reason);
            //printf(str);
            
            CFDictionaryRef currentRouting = CFDictionaryGetValue(inData, kAudioSession_AudioRouteChangeKey_CurrentRouteDescription);
            CFArrayRef outputs = CFDictionaryGetValue(currentRouting, kAudioSession_AudioRouteKey_Outputs);
            CFDictionaryRef outputTypeDict = CFArrayGetValueAtIndex(outputs, 0);     // TODO: this assumes a lot
            
            CFStringRef outputType = CFDictionaryGetValue(outputTypeDict, kAudioSession_AudioRouteKey_Type);
            //NSLog(@"Current output type: %@", outputType);
            
            if (CFStringCompare(outputType, kAudioSessionOutputRoute_Headphones, 0) == kCFCompareEqualTo)
            {
                UInt32 speaker = kAudioSessionOverrideAudioRoute_None;
                AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(speaker), &speaker);
            }
            else if (CFStringCompare(outputType, kAudioSessionOutputRoute_BuiltInReceiver, 0) == kCFCompareEqualTo)
            {
                UInt32 speaker = kAudioSessionOverrideAudioRoute_Speaker;
                AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(speaker), &speaker);
            }
            
        }
    }
    
}

#pragma mark - Ear Filtering Functions -
    
static float outerEarFilter(float input)
{
    //a(1)*y(n) = b(1)*x(n) + b(2)*x(n-1) + ... + b(nb+1)*x(n-nb) - a(2)*y(n-1) - ... - a(na+1)*y(n-na)
    static float o_x1 = 0.0;
    static float o_x2 = 0.0;
    static float o_y1 = 0.0;
    static float o_y2 = 0.0;
    float output = 0.0;
    
    output = (0.7221 * o_x1) + (-0.6918 * o_x2);
    
    o_x2 = o_x1;
    o_x1 = input;
    o_y2 = o_y1;
    o_y1 = output;
    
    return output;
}

static float middleEarFilter(float input)
{
    static float m_x1 = 0.0;
    static float m_x2 = 0.0;
    static float m_y1 = 0.0;
    static float m_y2 = 0.0;
    float output = 0.0;
    
    m_y1 = (0.8383 * input) + (-0.8383 * m_x2) - ( 0.6791 * m_y2);
    output = 0.6791 * m_y1;
    
    m_x2 = m_x1;
    m_x1 = input;
    m_y2 = m_y1;
    m_y1 = output;
    
    return output;
}

#pragma mark - Audio Model Init -

+ (BBAudioModel *)sharedAudioModel
{
    static BBAudioModel *sharedAudioModel = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedAudioModel = [[BBAudioModel alloc] init];
    });
    
    return sharedAudioModel;
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        sampleRate = 44100;
        blockSize = 256;                // equals hopsize also
        hopSize = blockSize;
        windowSize = 2 * hopSize;       // 2x overlap
        musicLibraryBuffer = (float *)calloc(NUM_SECONDS * sampleRate, sizeof(float));
        monoAnalysisBuffer = (float *)calloc(windowSize, sizeof(float));
        
        fft = newFFT(windowSize);
        createWindow(fft, HANN);
        fftFrame = newFFTFrame(fft);
        
        bark = newBark(windowSize, sampleRate);
        createBarkFilterbank(bark);
        
        mic = YES;
        music = NO;
        inputType = mic;
        canReadMusicFile = NO;                  // initially say that we can't read from this buffer
        peak_picker = newPeakPicker();
        
        gotOnset = NO;
        salience = 0.0;
        
        [self initTimer];
        
    }
    
    return self;
}


#pragma mark - Audio Model Dealloc -
- (void)dealloc
{
    free(musicLibraryBuffer);
    free(monoAnalysisBuffer);
    // free fft stuffs
    freeFFT(fft);
    freeFFTFrame(fftFrame);
    // free bark stuffs
    freeBark(bark);
    freePP(peak_picker);
}


#pragma mark - Audio Unit Setup -

- (void)setupAudioUnit
{
    AudioComponentDescription defaultOutputDescription;
    defaultOutputDescription.componentType = kAudioUnitType_Output;
    defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    defaultOutputDescription.componentFlags = 0;
    defaultOutputDescription.componentFlagsMask = 0;
    
    // Find and assign default output unit
    AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
    NSAssert(defaultOutput, @"-- Can't find a default output. --");
    
    // Create new audio unit that we'll use for output
    OSErr err = AudioComponentInstanceNew(defaultOutput, &bbUnit);
    NSAssert1(bbUnit, @"Error creating unit: %hd", err);
    
    // Enable IO for playback
    UInt32 flag = 1;
    err = AudioUnitSetProperty(bbUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flag, sizeof(flag));
    NSAssert1(err == noErr, @"Error setting output IO", err);
    
    // Enable IO for input / recording
    UInt32 enableInput = 1;
    AudioUnitElement inputBus = 1;
    AudioUnitSetProperty(bbUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, inputBus, &enableInput, sizeof(enableInput));
    
    // set format to 32 bit, single channel, floating point, linear PCM
    const int fourBytesPerFloat = 4;
    const int eightBitsPerByte = 8;
    
    AudioStreamBasicDescription streamFormat;
    streamFormat.mSampleRate =       44100;
    streamFormat.mFormatID =         kAudioFormatLinearPCM;
    streamFormat.mFormatFlags =      kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    streamFormat.mBytesPerPacket =   fourBytesPerFloat;
    streamFormat.mFramesPerPacket =  1;
    streamFormat.mBytesPerFrame =    fourBytesPerFloat;
    streamFormat.mChannelsPerFrame = 2;
    streamFormat.mBitsPerChannel =   fourBytesPerFloat * eightBitsPerByte;
    
    // set format for output (bus 0)
    err = AudioUnitSetProperty(bbUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, sizeof(AudioStreamBasicDescription));
    
    // set format for input (bus 1) 
    err = AudioUnitSetProperty(bbUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamFormat, sizeof(AudioStreamBasicDescription));
    NSAssert1(err == noErr, @"Error setting stream format: %hd", err);

    
    // Output
    // Setup rendering function on the unit
    AURenderCallbackStruct input;
    input.inputProc = renderCallback;
    input.inputProcRefCon = (__bridge void *)self;
    
    // This sets the audio unit render callback
    err = AudioUnitSetProperty(bbUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &input, sizeof(input));
    NSAssert1(err == noErr, @"Error setting callback: %hd", err);
    
    // Input
    // Setup audio input handling function
    // AUInputSample
    
    // Try setting up a post render callback
    //AudioUnitAddRenderNotify(bbUnit, postRenderCallback, (__bridge void *)self);
}

- (void)setupAudioSession
{
    OSStatus status;
    Float32 bufferDuration = (blockSize + 0.5) / sampleRate;           // add 0.5 to blockSize, need to so bufferDuration is correct value
    UInt32 category = kAudioSessionCategory_PlayAndRecord;
    //UInt32 category = kAudioSessionCategory_SoloAmbientSound;
    UInt32 speaker = kAudioSessionOverrideAudioRoute_Speaker;
    //UInt32 speaker = kAudioSessionOverrideAudioRoute_None;
    
    status = AudioSessionInitialize(NULL, NULL, NULL, (__bridge void *)self);
    status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    status = AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(speaker), &speaker);
    
    status = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(sampleRate), &sampleRate);
    status = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(bufferDuration), &bufferDuration);
    
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propertyListener, (__bridge void *)self);
    
    // TODO: Check where this should be set-able
    status = AudioSessionSetActive(true);
    
    //--------- Check everything
    Float64 audioSessionProperty64 = 0;
    Float32 audioSessionProperty32 = 0;
    UInt32 audioSessionPropertySize64 = sizeof(audioSessionProperty64);
    UInt32 audioSessionPropertySize32 = sizeof(audioSessionProperty32);
    
    status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &audioSessionPropertySize64, &audioSessionProperty64);
    NSLog(@"AudioSession === CurrentHardwareSampleRate: %.0fHz", audioSessionProperty64);
    
    sampleRate = audioSessionProperty64;
    
    status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, &audioSessionPropertySize32, &audioSessionProperty32);
    int blockSizeCheck = lrint(audioSessionProperty32 * audioSessionProperty64);
    NSLog(@"AudioSession === CurrentHardwareIOBufferDuration: %3.2fms", audioSessionProperty32 * 1000.0f);
    NSLog(@"AudioSession === block size: %i", blockSizeCheck);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setUpperThreshold:)
                                                 name:@"upper_threshold"
                                               object:nil];
    
}

- (void)setMicrophoneInput
{
    self.inputType = mic;
}

- (void)setMusicInput
{
    self.inputType = music;
}

- (void)setMusicLibraryDuration:(double)newMusicLibraryDuration
{
    musicLibraryDuration = newMusicLibraryDuration * sampleRate;
    musicLibraryCurrentPosition = 0;
}

- (double)musicLibraryDuration
{
    return musicLibraryDuration;
}

- (void)startAudioSession
{
    AudioSessionSetActive(true);
    
    // Start playback
    OSErr err = AudioOutputUnitStart(bbUnit);
    NSAssert1(err == noErr, @"Error starting unit: %hd", err);
}

- (void)startAudioUnit
{
    OSErr err = AudioUnitInitialize(bbUnit);
    NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
}

- (void)onsetDetected:(float)_salience
{
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:exp(_salience)] forKey:@"salience"];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"onsetDetected"
     object:nil
     userInfo:userInfo];

}

- (void)initTimer
{
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / (blockSize * 2.0))
                                     target:self selector:@selector(pollValues:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)pollValues:(NSTimer *)paramTimer
{
    if (gotOnset)
    {
        gotOnset = NO;
        [self onsetDetected:salience];
    }
}

- (void)setupMediaBuffers:(float *)readBuffer position:(int *)readPosition size:(int)size
{
    musicLibraryBuffer = readBuffer;
    musicLibraryReadPosition = readPosition;
    musicLibraryBufferSize = size;
    canReadMusicFile = NO;
}

- (void)clearMusicLibraryBuffer
{
    memset(musicLibraryBuffer, 0.0, sizeof(float) * musicLibraryBufferSize);
}

- (void) setUpperThreshold:(NSNotification *) notification
{
    if ([[notification name] isEqualToString:@"upper_threshold"]){
        
        NSNumber *thresh = [notification object];
        [BBAudioModel sharedAudioModel]->peak_picker->u_threshold = [thresh floatValue];
           
    }
        
}

@end
