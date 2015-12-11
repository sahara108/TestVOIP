//
//  IosAudioController.m
//  Aruts
//
//  Created by Simon Epskamp on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "IosAudioController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "EZAudioUtilities.h"
#import <UIKit/UIKit.h>
#import "EZAudioDevice.h"

#define kOutputBus 0
#define kInputBus 1

IosAudioController* iosAudio;

@interface IosAudioController ()

@property (nonatomic) AudioStreamBasicDescription speakerFormat;
@property (nonatomic) AudioStreamBasicDescription microphoneFormat;
@property (readonly, assign) AudioBufferList *tempBuffer;
@property (readonly) AudioComponentInstance audioUnit;

@property (nonatomic) EZAudioDevice *micDevice;
@property (nonatomic) EZAudioDevice *speakerDevice;

@end

void checkStatus(int status){
	if (status) {
		printf("Status not 0! %d\n", status);
	}
}

/**
 This callback is called when new audio data from the microphone is
 available.
 */
static OSStatus recordingCallback(void *inRefCon, 
                                  AudioUnitRenderActionFlags *ioActionFlags, 
                                  const AudioTimeStamp *inTimeStamp, 
                                  UInt32 inBusNumber, 
                                  UInt32 inNumberFrames, 
                                  AudioBufferList *ioData) {
    
    IosAudioController *microphone = (__bridge IosAudioController *)inRefCon;
    
    // render audio into buffer
    OSStatus result = AudioUnitRender(microphone.audioUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      microphone.tempBuffer);
    printf("action flag %d \n", *ioActionFlags);
    checkStatus(result);
    
    [microphone.dataSource microphone:microphone
                        hasBufferList:microphone.tempBuffer
                       withBufferSize:inNumberFrames
                 withNumberOfChannels:microphone.microphoneFormat.mChannelsPerFrame];
    
    return result;
}

/**
 This callback is called when the audioUnit needs new data to play through the
 speakers. If you don't have any, just don't write anything in the buffers
 */
static OSStatus playbackCallback(void *inRefCon, 
								 AudioUnitRenderActionFlags *ioActionFlags, 
								 const AudioTimeStamp *inTimeStamp, 
								 UInt32 inBusNumber, 
								 UInt32 inNumberFrames, 
								 AudioBufferList *ioData) {    
    
    IosAudioController *output = (__bridge IosAudioController *)inRefCon;
        
    TPCircularBuffer *circularBuffer = [output.dataSource outputShouldUseCircularBuffer:output];
    if( !circularBuffer ){
        //            SInt32 *left  = ioData->mBuffers[0].mData;
        //            SInt32 *right = ioData->mBuffers[1].mData;
        //            for(int i = 0; i < inNumberFrames; i++ ){
        //                left[  i ] = 0.0f;
        //                right[ i ] = 0.0f;
        //            }
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
        return noErr;
    };
    
    /**
     Thank you Michael Tyson (A Tasty Pixel) for writing the TPCircularBuffer, you are amazing!
     */
    
    // Get the available bytes in the circular buffer
    int32_t availableBytes;
    void *buffer = TPCircularBufferTail(circularBuffer,&availableBytes);
    int32_t amount = 0;
    //        float floatNumber = availableBytes * 0.25 / 48;
    //        float speakerNumber = ioData->mBuffers[0].mDataByteSize * 0.25 / 48;
    
    for (int i=0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer abuffer = ioData->mBuffers[i];
        
        // Ideally we'd have all the bytes to be copied, but compare it against the available bytes (get min)
        amount = MIN(abuffer.mDataByteSize,availableBytes);
        
        // copy buffer to audio buffer which gets played after function return
        memcpy(abuffer.mData, buffer, amount);
        
        // set data size
        abuffer.mDataByteSize = amount;
    }
    // Consume those bytes ( this will internally push the head of the circular buffer )
    TPCircularBufferConsume(circularBuffer,amount);
    return noErr;
}

void MyAudioUnitPropertyListenerProc(void *inRefCon, AudioUnit ci, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement)
{
    OSStatus	status;
    static OSStatus	lasterror = noErr;
    UInt32	size = sizeof(lasterror);
    OSStatus result = AudioUnitGetProperty(ci, inID, inScope, inElement, &lasterror, &size);
    checkStatus(result);
    if ((status == noErr) && (lasterror != noErr)) {
        fprintf(stderr, "unit %p reported error %d\n", ci, (int)lasterror);
    }
}

@implementation IosAudioController

+(instancetype)graphControllerWithDataSource:(id<IosAudioControllerDatasource>)datasource audioBasicStreamFormat:(AudioStreamBasicDescription)format micrcophoneFormat:(AudioStreamBasicDescription)micFormat
{
    IosAudioController *controller = [IosAudioController new];
    controller.speakerFormat = format;
    controller.microphoneFormat = format;
    controller.dataSource = datasource;
    [controller setup];
    
    return controller;
}


/**
 Initialize the audioUnit and allocate our own temporary buffer.
 The temporary buffer will hold the latest data coming in from the microphone,
 and will be copied to the output when this is requested.
 */
- (id) init {
	self = [super init];
	
	return self;
}

- (void)setup {
    OSStatus status;
    
    // Describe audio component
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    
    // Get audio units
    status = AudioComponentInstanceNew(inputComponent, &_audioUnit);
    checkStatus(status);
    
    // Enable IO for recording
    UInt32 flag = 1;
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &flag,
                                  sizeof(flag));
    checkStatus(status);
    
    // Enable IO for playback
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  kOutputBus,
                                  &flag,
                                  sizeof(flag));
    checkStatus(status);
    
    // Apply format
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &_speakerFormat,
                                  sizeof(self.speakerFormat));
    checkStatus(status);
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &_microphoneFormat,
                                  sizeof(self.microphoneFormat));
    checkStatus(status);
    
    
    // Set input callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = recordingCallback;
    callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    checkStatus(status);
    
    // Set output callback
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void * _Nullable)(self);
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &callbackStruct, 
                                  sizeof(callbackStruct));
    checkStatus(status);
    
    // Add the following to your graph construction code:
    AudioUnitAddPropertyListener(_audioUnit, kAudioUnitProperty_LastRenderError, &MyAudioUnitPropertyListenerProc, NULL);
    
    // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
    flag = 0;
    status = AudioUnitSetProperty(_audioUnit,
                                  kAudioUnitProperty_ShouldAllocateBuffer,
                                  kAudioUnitScope_Output, 
                                  kInputBus,
                                  &flag, 
                                  sizeof(flag));
    
    [self configureMicrophoneBufferList];
    
    // Initialise
    status = AudioUnitInitialize(_audioUnit);
    checkStatus(status);
}

-(void)configureMicrophoneBufferList
{
    UInt32 defaultBufferSize = 4096;
    UInt32 maximumBufferSize;
    
    UInt32 propSize = sizeof(maximumBufferSize);
    [EZAudioUtilities checkResult:AudioUnitGetProperty(_audioUnit,
                                                       kAudioUnitProperty_MaximumFramesPerSlice,
                                                       kAudioUnitScope_Global,
                                                       0,
                                                       &maximumBufferSize,
                                                       &propSize)
                        operation:"Failed to get maximum number of frames per slice"];
    
    UInt32 rightValue = MAX(defaultBufferSize, maximumBufferSize);
    BOOL isInterleaved = [EZAudioUtilities isInterleaved:self.microphoneFormat];
    UInt32 channels = self.microphoneFormat.mChannelsPerFrame;
    [EZAudioUtilities freeBufferList:self.tempBuffer];
    if (_tempBuffer != NULL) {
        for(unsigned i = 0; i < _tempBuffer->mNumberBuffers; i++)
        {
            free(_tempBuffer->mBuffers[i].mData);
        }
        free(_tempBuffer);
    }
    _tempBuffer = [EZAudioUtilities audioBufferListWithNumberOfFrames:rightValue
                                                                numberOfChannels:channels
                                                                     interleaved:isInterleaved];
    
    if ([self.dataSource respondsToSelector:@selector(microphone:hasAudioStreamBasicDescription:)]) {
        [self.dataSource microphone:self hasAudioStreamBasicDescription:_microphoneFormat];
    }
}

/**
 Start the audioUnit. This means data will be provided from
 the microphone, and requested for feeding to the speakers, by
 use of the provided callbacks.
 */
- (void) start {
	OSStatus status = AudioOutputUnitStart(_audioUnit);
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        NSArray *inputDevices = [EZAudioDevice inputDevices];
//        [self setMicrophoneDevice:[inputDevices lastObject]];
//        [self setSpeakerDevice:[EZAudioDevice currentOutputDevice]];
//    });
    
	checkStatus(status);
}

/**
 Stop the audioUnit
 */
- (void) stop {
	OSStatus status = AudioOutputUnitStop(_audioUnit);
	checkStatus(status);
}

-(void)setMute:(BOOL)on
{
    UInt32 onFlag = 1;
    UInt32 offFlag = 0;
    if (on) {
        AudioUnitSetProperty(_audioUnit,
                             kAUVoiceIOProperty_MuteOutput,
                             kAudioUnitScope_Input,
                             kInputBus,
                             &onFlag,
                             sizeof(onFlag));
    }else {
        AudioUnitSetProperty(_audioUnit,
                             kAUVoiceIOProperty_MuteOutput,
                             kAudioUnitScope_Input,
                             kInputBus,
                             &offFlag,
                             sizeof(offFlag));
    }
}

-(BOOL)isMuting
{
    UInt32 muting;
    UInt32 propSize = sizeof(muting);
    AudioUnitGetProperty(_audioUnit,
                         kAUVoiceIOProperty_MuteOutput,
                         kAudioUnitScope_Input,
                         kInputBus,
                         &muting,
                         &propSize);
    return muting > 0;
}

-(void)setMicrophoneDevice:(EZAudioDevice*)device
{
    // if the devices are equal then ignore
    if ([device isEqual:self.micDevice])
    {
        return;
    }
    _micDevice = device;
    
    NSError *error;
    [[AVAudioSession sharedInstance] setPreferredInput:device.port error:&error];
    if (error)
    {
        NSLog(@"Error setting input device port (%@), reason: %@",
              device.port,
              error.localizedDescription);
    }
    else
    {
        if (device.dataSource)
        {
            [[AVAudioSession sharedInstance] setInputDataSource:device.dataSource error:&error];
            if (error)
            {
                NSLog(@"Error setting input data source (%@), reason: %@",
                      device.dataSource,
                      error.localizedDescription);
            }
        }
    }
    
    if ([[AVAudioSession sharedInstance] isInputGainSettable]) {
        [[AVAudioSession sharedInstance] setInputGain:1 error:nil];
    }
}

-(void)setSpeakerDevice:(EZAudioDevice*)device
{
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
//    
//    if (!device) {
//        return;
//    }
//    if ([device isEqual:self.speakerDevice])
//    {
//        return;
//    }
//    _speakerDevice = device;
//    
//    NSError *error;
//    [[AVAudioSession sharedInstance] setOutputDataSource:device.dataSource error:&error];
//    if (error)
//    {
//        NSLog(@"Error setting output device data source (%@), reason: %@",
//              device.dataSource,
//              error.localizedDescription);
//    }
}

/**
 Clean up.
 */
- (void) dealloc {
    if (_tempBuffer != NULL) {
        for(unsigned i = 0; i < _tempBuffer->mNumberBuffers; i++)
        {
            free(_tempBuffer->mBuffers[i].mData);
        }
        free(_tempBuffer);
    }
    
    AudioUnitUninitialize(_audioUnit);
	AudioComponentInstanceDispose(_audioUnit);
}

@end
