//
//  BBMediaPlayer.m
//  Bubble Beat
//
//  Created by Scott McCoid on 5/13/13.
//
//

#import "BBMediaPlayer.h"
#import "BBAudioModel.h"

@implementation BBMediaPlayer

@synthesize playing;
@synthesize mediaReadPosition;
@synthesize artist;
@synthesize title;
@synthesize mediaLength;
@synthesize bufferingAmount;
@synthesize mediaBuffer;
@synthesize mediaFileDuration;
@synthesize parentViewController;       // this is a hack, blegh
@synthesize newFileSelected;
@synthesize fileFinished;
@synthesize restartSong;
@synthesize initialRead;
@synthesize loadingInBackground;

- (id)init
{
    self = [super init];
    if (self)
    {
        // Allocate queue for loading/streaming audio file
        queue = [[NSOperationQueue alloc] init];
        
        // Setup audio setting information
        //http://objective-audio.jp/2010/09/avassetreaderavassetwriter.html
        audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithFloat:44100.0],AVSampleRateKey,
                        [NSNumber numberWithInt:2],AVNumberOfChannelsKey,
                        [NSNumber numberWithInt:32],AVLinearPCMBitDepthKey,
                        [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                        [NSNumber numberWithBool:YES], AVLinearPCMIsFloatKey,
                        [NSNumber numberWithBool:0], AVLinearPCMIsBigEndianKey,
                        [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                        [NSData data], AVChannelLayoutKey, nil];
        
        bufferingAmount = DEFAULT_BUFFERING_AMOUNT * SAMPLE_RATE * 2.0;             // Assuming it's always a stereo file
        mediaBuffer = (float *)calloc(bufferingAmount, sizeof(float));
        
        // Set the write/read positions to 0
        mediaWritePosition = 0;
        mediaReadPosition = 0;
        
        // Setup initial states
        playing = NO;
        newFileSelected = NO;
        fileFinished = YES;
        restartSong = NO;
        initialRead = NO;        
        loadingInBackground = NO;
        
        // setup information for audio model
        [[BBAudioModel sharedAudioModel] setupMediaBuffers:mediaBuffer position:&mediaReadPosition size:bufferingAmount];

    }
    
    return self;
}

- (void)dealloc
{
    free(mediaBuffer);
}

- (void)zeroMediaBuffer
{
    memset(mediaBuffer, 0, sizeof(float) * bufferingAmount);    
}

#pragma mark - Media File Loading -

- (void)audioFileProblem
{
    artist = @"Error";
    title = @"Loading File";
}

- (void)startLoadingFile
{
    NSInvocationOperation *operation = [[NSInvocationOperation alloc]
										initWithTarget:self
										selector:@selector(loadAudioFile)
										object:nil];
    [queue addOperation:operation];
}


- (void)loadAudioFile
{
	
	loadingInBackground = YES;
    fileFinished = NO;
	
	//http://developer.apple.com/library/ios/#documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/05_MediaRepresentations.html
	NSDictionary* options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
	AVURLAsset* asset = [AVURLAsset URLAssetWithURL:currentSongURL options:options];
	
	NSError *error = nil;
	AVAssetReader* filereader = [AVAssetReader assetReaderWithAsset:(AVAsset *)asset error:&error];
    
	if (error == nil)
    {
        @autoreleasepool
        {
            //should only be one track anyway
            AVAssetReaderAudioMixOutput* readAudioFile = [AVAssetReaderAudioMixOutput
                                                          assetReaderAudioMixOutputWithAudioTracks:(asset.tracks)
                                                          audioSettings:audioSetting];
            
            if ([filereader canAddOutput:(AVAssetReaderOutput *)readAudioFile] == NO)
                [self audioFileProblem];
            
            [filereader addOutput:(AVAssetReaderOutput *)readAudioFile];
            
            if ([filereader startReading] == NO)
                [self audioFileProblem];
            
            //take large chunks of data at a time
            //http://osdir.com/ml/coreaudio-api/2009-10/msg00030.html            
            // Iteratively read data from the input file and write to output
            for(;;)
            {
                if (!playing)
                {
                    // while playing flag is set at NO, just hang around
                    [BBAudioModel sharedAudioModel].canReadMusicFile = NO;
                    while (playing == NO && fileFinished == NO)
                    {
                        usleep(1000);            // TODO: This is the best option I can think of at the moment, maybe not ideal
                    }
                    
                }
                
                if (restartSong)
                {
                    [BBAudioModel sharedAudioModel].canReadMusicFile = NO;
                    [self zeroMediaBuffer];
                    [[BBAudioModel sharedAudioModel] clearMusicLibraryBuffer];
                    initialRead = NO;
                    
                    //a lot of repeat to code to restart: should really encapsulate in a class
                    [filereader cancelReading];
                    filereader = [AVAssetReader assetReaderWithAsset:(AVAsset *)asset error:&error];
                    
                    if (error != nil)
                        [self audioFileProblem];
                    
                    readAudioFile = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:(asset.tracks) audioSettings:audioSetting];
                    
                    if ([filereader canAddOutput:(AVAssetReaderOutput *)readAudioFile] == NO)
                        [self audioFileProblem];
                    
                    [filereader addOutput:(AVAssetReaderOutput *)readAudioFile];
                    
                    if ([filereader startReading] == NO)
                        [self audioFileProblem];
                    
                    restartSong = NO;
                    fileFinished = NO;      // not sure why it'd be finished, but whatevs
                    
                    //thread safety, wat?
                    mediaWritePosition = (mediaReadPosition + 1024) % bufferingAmount;
                }
                
//                int readTest = sampleReadPosition;
                int readTest = mediaReadPosition;
                
                // test where readpos_ is; while within 2 seconds (half of buffer) must continue to fill up
                // god, this is an ugly expression
                int diff = readTest <= mediaWritePosition ? (mediaWritePosition - readTest):(mediaWritePosition + bufferingAmount - readTest);
                
                // If our difference is less than an amount, then we need to rebuffer
                // else sleep and wait around
                if (diff < bufferingAmount / 4 && fileFinished == NO)
                {
                    CMSampleBufferRef ref = [readAudioFile copyNextSampleBuffer];
                    if (ref != NULL)
                    {
                        //finished?
                        if (CMSampleBufferDataIsReady(ref) == NO)
                            [self audioFileProblem];
                        
                        CMItemCount countsamp= CMSampleBufferGetNumSamples(ref);
                        UInt32 frameCount = countsamp;
                        
                        CMBlockBufferRef blockBuffer;
                        AudioBufferList audioBufferList;
                        
                        //allocates new buffer memory
                        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(ref, NULL, &audioBufferList, sizeof(audioBufferList),NULL, NULL, 0, &blockBuffer);
                        
                        float* buffer = (float *)audioBufferList.mBuffers[0].mData;
                        
                        for (int i = 0; i < (2 * frameCount); ++i)
                        {
                            mediaBuffer[mediaWritePosition] = buffer[i];
                            mediaWritePosition = (mediaWritePosition + 1) % bufferingAmount;
                        }
                        
                        CFRelease(ref);
                        CFRelease(blockBuffer);
                        
                        // If no frames were returned, conversion is finished
                        if(frameCount == 0)
                            fileFinished = YES;
                    }
                    else
                    {
                        fileFinished = YES;
                    }
                    
                }
                else
                {
                    if (!initialRead)
                    {
                        initialRead = YES;
                        [BBAudioModel sharedAudioModel].canReadMusicFile = YES;
                    }
                    else if (!fileFinished)
                    {
                        usleep(100);
                        if ([BBAudioModel sharedAudioModel].canReadMusicFile == NO)
                            fileFinished = YES;
                    }
                }
                
                // when finished set to YES, break out of for loop
                if (fileFinished)
                {
                    [[BBAudioModel sharedAudioModel] clearMusicLibraryBuffer];
                    [self zeroMediaBuffer];
                    break;
                }
            }
            
            
        }
        
		[filereader cancelReading];
		loadingInBackground = NO;
        
        // reset the track and set state to pause
        [self reset];
        [self pause];
        
        // notify songFinished that we're done
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"songFinished"
         object:nil];
        
		return;
    }
    else
    {
        [self audioFileProblem];
    }
	
}


#pragma mark - API Methods -

- (void)play
{    
    // start background process to load audio file if new file recently loaded
    if (newFileSelected)
    {
        [self startLoadingFile];
        newFileSelected = NO;
    }
    else if (fileFinished == YES && currentSongURL != nil)    // TODO: wat?
    {
        [self exportAssetAtURL:currentSongURL];
        [self startLoadingFile];
    }
    
    playing = YES;
}

- (void)pause
{
    playing = NO;                    // just setting this to NO is enough to pause the playback in loadAudioFile
}

- (void)reset
{
    restartSong = YES;
}

- (void)showMediaPicker
{
    mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    mediaPicker.delegate = self;
    [mediaPicker setAllowsPickingMultipleItems:NO];
    [parentViewController presentViewController:mediaPicker animated:YES completion:NULL];
}


- (void)exportAssetAtURL:(NSURL*)assetURL
{
    [[BBAudioModel sharedAudioModel] setMusicLibraryDuration:mediaFileDuration];
    [[BBAudioModel sharedAudioModel] setCanReadMusicFile:NO];

    mediaWritePosition = 0;
    mediaReadPosition = 0;
	initialRead = NO;

    // zero out everything
    [self zeroMediaBuffer];

}

- (void)freeAudio
{
    if (playing)
    {
        playing = NO;
        [[BBAudioModel sharedAudioModel] setCanReadMusicFile:NO];
    }
    
    fileFinished = YES;
    while (loadingInBackground)
    {
        usleep(1000);
    }
    
    //stop background loading thread
//	if(loadingInBackground == YES)
//		earlyFinish = YES;
//    
//	while(loadingInBackground == YES)
//	{
//		usleep(5000); //wait for file thread to finish
//	}
}

#pragma mark - Media Picking Delegate Methods -

- (void)mediaPicker:(MPMediaPickerController *)inputMediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
	for (MPMediaItem* item in mediaItemCollection.items)
    {
        
		title = [item valueForProperty:MPMediaItemPropertyTitle];
		artist = [item valueForProperty:MPMediaItemPropertyArtist];
		mediaFileDuration = [[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
		
		//MPMediaItemPropertyArtist
		currentSongURL = [item valueForProperty:MPMediaItemPropertyAssetURL];
		if (nil == currentSongURL)
        {
            [self audioFileProblem];
			return;
		}
        
        [self exportAssetAtURL:currentSongURL];
        newFileSelected = YES;
	}
    
    // If we're currently playing a song, we need to stop playing
    [self freeAudio];
    
    // Dismiss the media picker's view
    [inputMediaPicker dismissViewControllerAnimated:YES completion:NULL];
    
    // Tell whoever's listening that we're done with the media picker
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"mediaPickerFinished"
     object:nil];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)inputMediaPicker
{
    [inputMediaPicker dismissViewControllerAnimated:YES completion:NULL];    
}

@end
